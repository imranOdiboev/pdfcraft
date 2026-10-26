<# Mandatory real-button cancellation on disposable CI. No install is initiated.
   LegacyButtonFilter restores the old discovery bug for an explicit negative control.
   Forced termination is failure cleanup only, never cancellation evidence. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SetupPath,
    [Parameter(Mandatory)][string]$CancelRoot,
    [Parameter(Mandatory)][string]$QaDir,
    [ValidateRange(1,5)][int]$Iterations = 3,
    [switch]$LegacyButtonFilter
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -cne 'true' -or -not $IsWindows -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted') { throw 'Disposable Windows CI only.' }
foreach ($path in @($CancelRoot, $QaDir)) {
    $full = [IO.Path]::GetFullPath($path)
    $allowed = @($env:RUNNER_TEMP, $env:GITHUB_WORKSPACE) | Where-Object { $_ } | ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd('\') + '\' }
    if (-not @($allowed | Where-Object { $full.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count) { throw 'Cancellation output must stay in the disposable runner workspace or temp.' }
}
$SetupPath = (Resolve-Path -LiteralPath $SetupPath).Path
if (Test-Path -LiteralPath $CancelRoot) { throw 'Cancellation requires a fresh output root.' }
New-Item -ItemType Directory -Path $CancelRoot,$QaDir -Force | Out-Null
. (Join-Path $PSScriptRoot 'trace-odibo-setup.ps1') -LibraryOnly
$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{A7A4DC1B-3255-4BC6-9F6F-1DA0B61B6524}_is1'
if (Test-Path -LiteralPath $registryPath) { throw 'A registered installation already exists; refusing cancellation fixture.' }
$report = [ordered]@{ status='running'; legacy_button_filter=[bool]$LegacyButtonFilter; user_interactive=[Environment]::UserInteractive; runner_session=[Diagnostics.Process]::GetCurrentProcess().SessionId; attempts=[Collections.Generic.List[object]]::new() }
try {
    $languages = if ($LegacyButtonFilter) { @('selection') } else { @('selection','en','ru') }
    foreach ($language in $languages) {
        for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
            $destination = Join-Path $CancelRoot ($language + '-' + $iteration)
            $attempt = [ordered]@{ language=$language; iteration=$iteration; status='running'; deadline_seconds=45; actions=[Collections.Generic.List[object]]::new(); samples=[Collections.Generic.List[object]]::new(); legacy_filtered_visible_cancel=$false; cleanup_termination=$false }
            $report.attempts.Add($attempt)
            $start = [Diagnostics.ProcessStartInfo]::new($SetupPath)
            $start.UseShellExecute = $false
            $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Normal
            foreach ($argument in @('/CURRENTUSER','/NORESTART','/SP-',('/DIR=' + $destination),('/LOG=' + (Join-Path $CancelRoot ($language + '-' + $iteration + '.log'))))) { [void]$start.ArgumentList.Add($argument) }
            if ($language -ne 'selection') { [void]$start.ArgumentList.Add('/LANG=' + $language) }
            $process = [Diagnostics.Process]::Start($start)
            $owned = [Collections.Generic.HashSet[int]]::new()
            [void]$owned.Add($process.Id)
            $births = @{}
            $watch = [Diagnostics.Stopwatch]::StartNew()
            $cancelPosted = $false
            $confirmationPosted = $false
            $lastDiagnostic = -5000L
            $frame = $null
            try {
                while (-not $process.HasExited -and $watch.Elapsed.TotalSeconds -lt 45) {
                    $snapshot = @(Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,SessionId,Name,CreationDate)
                    # Follow the complete observed bootstrap tree, not an arbitrary depth.
                    # Bind retained PIDs to birth times so PID reuse cannot authorize a click.
                    $rootEntry = @($snapshot | Where-Object { $_.ProcessId -eq $process.Id })
                    if (-not $births.ContainsKey($process.Id) -and $rootEntry.Count -eq 1) { $births[$process.Id] = $rootEntry[0].CreationDate }
                    do {
                        $before = $owned.Count
                        foreach ($entry in $snapshot) {
                            $parentId = [int]$entry.ParentProcessId
                            if (-not $births.ContainsKey($parentId)) { continue }
                            $parent = @($snapshot | Where-Object { $_.ProcessId -eq $parentId -and $_.CreationDate -eq $births[$parentId] })
                            if ($parent.Count -eq 1 -and $entry.CreationDate -ge $parent[0].CreationDate -and $entry.SessionId -eq $process.SessionId) {
                                [void]$owned.Add([int]$entry.ProcessId)
                                if (-not $births.ContainsKey([int]$entry.ProcessId)) { $births[[int]$entry.ProcessId] = $entry.CreationDate }
                            }
                        }
                    } while ($owned.Count -ne $before)
                    $liveOwned = [Collections.Generic.HashSet[int]]::new()
                    foreach ($entry in $snapshot) { if ($births.ContainsKey([int]$entry.ProcessId) -and $births[[int]$entry.ProcessId] -eq $entry.CreationDate) { [void]$liveOwned.Add([int]$entry.ProcessId) } }
                    $frame = Get-OdiboSetupSnapshot $liveOwned $watch.ElapsedMilliseconds
                    $frame.processes = @($snapshot | Where-Object { $liveOwned.Contains([int]$_.ProcessId) })
                    if ($watch.ElapsedMilliseconds - $lastDiagnostic -ge 5000) { $attempt.samples.Add($frame); $lastDiagnostic = $watch.ElapsedMilliseconds }
                    foreach ($window in $frame.windows) {
                        if (-not $window.visible -or -not $window.enabled) { continue }
                        foreach ($element in $window.uia) {
                            $name = $element.name.Replace('&','').Trim()
                            $isCancel = -not $cancelPosted -and $name -cmatch '^(Cancel|Отмена)$'
                            $isYes = $cancelPosted -and -not $confirmationPosted -and $name -cmatch '^(Yes|Да)$'
                            if (-not ($isCancel -or $isYes)) { continue }
                            if ($isCancel -and $window.class -cnotin @('TSelectLanguageForm','TWizardForm')) { continue }
                            if ($isYes -and $window.class -cnotin @('TSetupMessageForm','#32770','TMessageForm')) { continue }
                            $handle = [IntPtr][long]$element.handle
                            if ($handle -eq [IntPtr]::Zero) { continue }
                            [uint32]$buttonProcess = 0
                            [void][OdiboSetupTrace]::GetWindowThreadProcessId($handle,[ref]$buttonProcess)
                            $class = [OdiboSetupTrace]::Class($handle)
                            if (-not $liveOwned.Contains([int]$buttonProcess) -or $buttonProcess -ne $window.process_id -or -not [OdiboSetupTrace]::IsChild([IntPtr][long]$window.handle,$handle)) { continue }
                            if ($class -cnotin @('TNewButton','Button') -or -not $element.enabled -or $element.offscreen -or -not [OdiboSetupTrace]::IsWindowVisible($handle) -or -not [OdiboSetupTrace]::IsWindowEnabled($handle)) { continue }
                            # Inno TNewButton is exposed as UIA Pane, not Button; use its
                            # verified native identity rather than trusting ControlType alone.
                            if ($LegacyButtonFilter -and $element.type -cne 'ControlType.Button') { $attempt.legacy_filtered_visible_cancel=$true; continue }
                            [void][OdiboSetupTrace]::SetForegroundWindow([IntPtr][long]$window.handle)
                            if (-not [OdiboSetupTrace]::PostMessage($handle,0x00F5,[IntPtr]::Zero,[IntPtr]::Zero)) { throw 'Could not post the actual owned button click.' }
                            $attempt.samples.Add($frame)
                            $attempt.actions.Add([ordered]@{ elapsed_ms=$watch.ElapsedMilliseconds; action=if($isCancel){'Cancel'}else{'Confirm Yes'}; process_id=$buttonProcess; window_class=$window.class; handle=$handle.ToInt64(); name=$name; uia_type=$element.type; native_class=$class; method='asynchronous native BM_CLICK to the actual owned UIA-identified button' })
                            if ($isCancel) { $cancelPosted=$true } else { $confirmationPosted=$true }
                            break
                        }
                    }
                    Start-Sleep -Milliseconds 250
                }
                if (-not $cancelPosted) { throw 'Could not activate the real setup Cancel button.' }
                if (-not $process.WaitForExit(10000)) { throw 'Setup did not exit after real Cancel.' }
                $attempt.exit_code = $process.ExitCode
                # Language-dialog cancellation is initialization abort (1); wizard Cancel
                # before installation is 2. Neither any nonzero error nor a killed process
                # is accepted as proof. Explicit languages must confirm the wizard prompt.
                $expectedExit = if ($language -eq 'selection') { 1 } else { 2 }
                if ($process.ExitCode -ne $expectedExit) { throw 'Setup did not report the expected native cancellation exit code.' }
                if ($language -ne 'selection' -and -not $confirmationPosted) { throw 'Wizard cancellation confirmation was not activated.' }
                if (Test-Path -LiteralPath $registryPath) { throw 'Cancelled Setup registered an installation.' }
                if (Test-Path -LiteralPath $destination) { throw 'Cancelled Setup created the destination directory.' }
                foreach ($entry in $snapshot) {
                    if ($liveOwned.Contains([int]$entry.ProcessId) -and $entry.ProcessId -ne $process.Id) {
                        $remaining = Get-Process -Id $entry.ProcessId -ErrorAction SilentlyContinue
                        if ($remaining -and -not $remaining.HasExited) { throw 'An owned Setup child remains after cancellation.' }
                    }
                }
                $attempt.status='passed'
                Write-Host "PASS real Setup Cancel: $language iteration $iteration; exit $($process.ExitCode); no installation or forced termination."
            } catch {
                $attempt.status='failed'
                $attempt.error=$_.Exception.Message
                $attempt.elapsed_ms=$watch.ElapsedMilliseconds
                # Last discovery frame contains only owned processes and controls.
                if ($null -ne $frame) { $attempt.samples.Add($frame) }
                throw
            } finally {
                if (-not $process.HasExited) { $attempt.cleanup_termination=$true; $process.Kill($true); [void]$process.WaitForExit(5000) }
                $process.Dispose()
            }
        }
    }
    $report.status='passed'
} catch {
    $report.status='failed'
    $report.error=$_.Exception.Message
    throw
} finally {
    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $QaDir 'setup-cancellation.json') -Encoding utf8NoBOM
}
[pscustomobject]@{ status=$report.status; passed=$report.attempts.Count; repetitions_per_scenario=$Iterations; scenarios=@($languages) }
