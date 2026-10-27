<# Real silent refusal regression on disposable CI only. An expected blocking
   baseline is diagnostic evidence, never successful installation/cancellation. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SetupPath, [Parameter(Mandatory)][string]$WorkRoot,
      [Parameter(Mandatory)][string]$QaDir, [switch]$ExpectBlockingRegression)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -cne 'true' -or -not $IsWindows -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted') { throw 'Disposable Windows CI only.' }
$root=[IO.Path]::GetFullPath($WorkRoot)
$temp=[IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\')+'\'
if (-not $root.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $root)) { throw 'Refusal fixture requires a fresh runner temp directory.' }
$qa=[IO.Path]::GetFullPath($QaDir)
$workspace=[IO.Path]::GetFullPath($env:GITHUB_WORKSPACE).TrimEnd('\')+'\'
if (-not $qa.StartsWith($workspace,[StringComparison]::OrdinalIgnoreCase)) { throw 'QA must stay in the runner workspace.' }
New-Item -ItemType Directory -Path $root,$qa -Force | Out-Null
. (Join-Path $PSScriptRoot 'trace-odibo-setup.ps1') -LibraryOnly
$registry='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{A7A4DC1B-3255-4BC6-9F6F-1DA0B61B6524}_is1'
if (Test-Path -LiteralPath $registry) { throw 'Registered installer must be absent before refusal test.' }
$records=[Collections.Generic.List[object]]::new()
$report=[ordered]@{status='running'; expected_blocking_regression=[bool]$ExpectBlockingRegression; cases=$records}
try {
    $languages=if($ExpectBlockingRegression){@('en')}else{@('en','ru')}
    foreach($language in $languages) {
        $destination=Join-Path $root ('Неприкосновенная Portable '+$language)
        New-Item -ItemType Directory -Path $destination | Out-Null
        $marker=Join-Path $destination 'portable.txt'
        $sentinel=Join-Path $destination 'unknown-user-data.txt'
        [IO.File]::WriteAllText($marker,'Synthetic existing portable marker')
        [IO.File]::WriteAllText($sentinel,'Synthetic user data: must survive rejection')
        $hashes=@{}
        foreach($path in @($marker,$sentinel)){ $hashes[$path]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
        $log=Join-Path $root ($language+'.log')
        $start=[Diagnostics.ProcessStartInfo]::new((Resolve-Path -LiteralPath $SetupPath).Path)
        $start.UseShellExecute=$false; $start.CreateNoWindow=$true; $start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
        foreach($arg in @('/CURRENTUSER','/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',('/LANG='+$language),('/DIR='+$destination),('/LOG='+$log))){[void]$start.ArgumentList.Add($arg)}
        $process=[Diagnostics.Process]::Start($start)
        $owned=[Collections.Generic.HashSet[int]]::new();[void]$owned.Add($process.Id)
        $watch=[Diagnostics.Stopwatch]::StartNew()
        $record=[ordered]@{language=$language;status='running';timeout_seconds=30;cleanup_termination=$false;samples=[Collections.Generic.List[object]]::new();observed_blocking_folder_error=$false}
        $records.Add($record)
        $blockingButton=$null
        try {
            while(-not $process.HasExited -and $watch.Elapsed.TotalSeconds -lt 30) {
                $snapshot=@(Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,SessionId,Name)
                do {$before=$owned.Count;foreach($entry in $snapshot){if($owned.Contains([int]$entry.ParentProcessId)){[void]$owned.Add([int]$entry.ProcessId)}}}while($owned.Count -ne $before)
                $frame=Get-OdiboSetupSnapshot $owned $watch.ElapsedMilliseconds
                $frame.processes=@($snapshot|Where-Object{$owned.Contains([int]$_.ProcessId)})
                $record.samples.Add($frame)
                foreach($window in $frame.windows) {
                    if(-not $window.visible -or -not $window.enabled -or $window.class -cnotin @('TSetupMessageForm','#32770','TMessageForm')){continue}
                    $expectedText='Choose a new, empty application folder. Do not select a portable copy, a document folder, a profile root, or a system folder.'
                    if(-not @($window.uia|Where-Object{$_.name -ceq $expectedText}).Count){continue}
                    foreach($element in $window.uia) {
                        if($element.name.Replace('&','').Trim() -cne 'OK' -or -not $element.enabled -or $element.offscreen){continue}
                        $handle=[IntPtr][long]$element.handle
                        [uint32]$buttonProcess=0
                        [void][OdiboSetupTrace]::GetWindowThreadProcessId($handle,[ref]$buttonProcess)
                        if($owned.Contains([int]$buttonProcess) -and $buttonProcess -eq $window.process_id -and [OdiboSetupTrace]::IsChild([IntPtr][long]$window.handle,$handle) -and [OdiboSetupTrace]::Class($handle) -cin @('TNewButton','Button') -and [OdiboSetupTrace]::IsWindowVisible($handle) -and [OdiboSetupTrace]::IsWindowEnabled($handle)) {
                            $record.observed_blocking_folder_error=$true
                            $blockingButton=$handle
                        }
                    }
                }
                Start-Sleep -Milliseconds 500
            }
            $record.elapsed_ms=$watch.ElapsedMilliseconds
            if($ExpectBlockingRegression) {
                if($process.HasExited -or -not $record.observed_blocking_folder_error){throw 'Original unsuppressible folder-error modal was not reproduced.'}
                if(-not [OdiboSetupTrace]::PostMessage($blockingButton,0x00F5,[IntPtr]::Zero,[IntPtr]::Zero)){throw 'Could not acknowledge the observed blocking error for diagnostic cleanup.'}
                if(-not $process.WaitForExit(10000) -or $process.ExitCode -ne 1){throw 'Baseline did not return native initialization refusal after error acknowledgment.'}
                $record.diagnostic_cleanup='Actual owned OK after 30-second blocking proof; NOT automatic refusal or Cancel.'
                $record.exit_code=$process.ExitCode
                $record.status='observed blocking regression; NOT successful refusal'
            } else {
                if(-not $process.HasExited){throw 'Silent unsafe-folder refusal timed out.'}
                $record.exit_code=$process.ExitCode
                if($process.ExitCode -ne 1){throw 'Unexpected silent pre-install refusal exit code.'}
                if(-not [IO.File]::ReadAllText($log).Contains('ODIBO_FOLDER_REFUSED: ')){throw 'Missing specific folder-refusal evidence in private setup log.'}
                $record.status='passed'
            }
            if(Test-Path -LiteralPath $registry){throw 'Rejected setup registered an installation.'}
            if(Test-Path -LiteralPath (Join-Path $destination 'odibo-pdf.exe')){throw 'Rejected setup wrote application payload.'}
            $files=@(Get-ChildItem -LiteralPath $destination -Recurse -File -Force)
            if($files.Count -ne 2){throw 'Rejected setup changed destination inventory.'}
            foreach($path in @($marker,$sentinel)){if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]){throw 'Rejected setup modified original data.'}}
            if($ExpectBlockingRegression){Write-Host 'Observed original blocking modal; diagnostic cleanup is NOT successful refusal.'}
            else{Write-Host ('PASS actual silent refusal: '+$language+'; no installation, no data changes, no forced termination.')}
        } catch {$record.status='failed';$record.error=$_.Exception.Message;throw}
        finally {if(-not $process.HasExited){$record.cleanup_termination=$true;$process.Kill($true);[void]$process.WaitForExit(5000)};$process.Dispose()}
    }
    $report.status=if($ExpectBlockingRegression){'negative-control reproduced'}else{'passed'}
} catch {$report.status='failed';$report.error=$_.Exception.Message;throw}
finally {$report|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $qa 'setup-refusal.json') -Encoding utf8NoBOM}
