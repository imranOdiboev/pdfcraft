<# File-sharing regression on disposable Windows CI. It never launches an app. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$QaDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -cne 'true' -or -not $IsWindows -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted') { throw 'Disposable Windows CI only.' }
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$qa = [IO.Path]::GetFullPath($QaDir)
$workspace = [IO.Path]::GetFullPath($env:GITHUB_WORKSPACE).TrimEnd('\') + '\'
Require ($qa.StartsWith($workspace, [StringComparison]::OrdinalIgnoreCase)) 'QA must stay in runner workspace.'
[void][IO.Directory]::CreateDirectory($qa)
$root = Join-Path $env:RUNNER_TEMP ('odibo-sharing-test-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
$file = Join-Path $root 'test-data.dat'
[IO.File]::WriteAllText($file, 'Synthetic file contents; the test must not change these bytes.')
$hash = (Get-FileHash -LiteralPath $file).Hash
. (Join-Path $PSScriptRoot 'wait-odibo-executable-ready.ps1')
$report = [ordered]@{ status = 'running'; application_executed = $false; checks = [Collections.Generic.List[object]]::new() }
try {
    $ready = Wait-OdiboExecutableReady -Path $file -TimeoutMilliseconds 1000
    Require ($ready.status -ceq 'passed' -and $ready.attempts -eq 1) 'An already available file should not incur a forced delay.'
    $report.checks.Add([ordered]@{ name = 'immediately available'; status = 'passed' })

    $message = $null
    try { [void](Wait-OdiboExecutableReady -Path (Join-Path $root 'missing.dat') -TimeoutMilliseconds 1000 -DiagnosticPath (Join-Path $qa 'missing-file.json')) }
    catch { $message = $_.Exception.Message }
    Require ($message -ceq 'Executable could not be checked for exclusive access after normal shutdown.') 'A missing file did not fail for the intended reason.'
    $missing = Get-Content -LiteralPath (Join-Path $qa 'missing-file.json') -Raw | ConvertFrom-Json
    Require ($missing.status -ceq 'failed' -and $missing.first_win32_error -eq 2 -and $missing.attempts -eq 1) 'Missing file should fail immediately without retries.'
    $report.checks.Add([ordered]@{ name = 'missing file fails immediately'; status = 'passed' })

    $held = [IO.File]::Open($file, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $message = $null
        try { [void](Wait-OdiboExecutableReady -Path $file -TimeoutMilliseconds 250 -DiagnosticPath (Join-Path $qa 'persistent-lock.json')) }
        catch { $message = $_.Exception.Message }
        Require ($message -ceq 'Executable remained in use after normal shutdown.') 'A persistent lock did not fail for the intended reason.'
        $failure = Get-Content -LiteralPath (Join-Path $qa 'persistent-lock.json') -Raw | ConvertFrom-Json
        Require ($failure.status -ceq 'failed' -and $failure.first_win32_error -eq 32 -and $failure.attempts -gt 1) 'Persistent sharing violation evidence is incomplete.'
        $report.checks.Add([ordered]@{ name = 'persistent lock fails without modifying the file'; status = 'passed'; attempts = $failure.attempts; elapsed_ms = $failure.elapsed_ms })
    } finally { $held.Dispose() }

    $held = [IO.File]::Open($file, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $worker = [PowerShell]::Create()
    [void]$worker.AddScript('param($stream) Start-Sleep -Milliseconds 1500; $stream.Dispose()').AddArgument($held)
    $async = $worker.BeginInvoke()
    try {
        $message = $null
        try { [void](Wait-OdiboExecutableReady -Path $file -TimeoutMilliseconds 250 -DiagnosticPath (Join-Path $qa 'late-release.json')) }
        catch { $message = $_.Exception.Message }
        Require ($message -ceq 'Executable remained in use after normal shutdown.') 'A release after the deadline must not pass.'
        [void]$worker.EndInvoke($async)
        $late = Get-Content -LiteralPath (Join-Path $qa 'late-release.json') -Raw | ConvertFrom-Json
        Require ($late.status -ceq 'failed' -and $late.first_win32_error -eq 32) 'Late release did not preserve failure evidence.'
        $report.checks.Add([ordered]@{ name = 'release after deadline remains a failure'; status = 'passed'; elapsed_ms = $late.elapsed_ms })
    } finally {
        if (-not $async.IsCompleted) { $worker.Stop() }
        $worker.Dispose()
        $held.Dispose()
    }

    for ($i = 1; $i -le 3; $i++) {
        $held = [IO.File]::Open($file, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $worker = [PowerShell]::Create()
        [void]$worker.AddScript('param($stream) Start-Sleep -Milliseconds 800; $stream.Dispose()').AddArgument($held)
        $async = $worker.BeginInvoke()
        try {
            $result = Wait-OdiboExecutableReady -Path $file -TimeoutMilliseconds 10000 -DiagnosticPath (Join-Path $qa ('released-lock-' + $i + '.json'))
            [void]$worker.EndInvoke($async)
            $evidence = Get-Content -LiteralPath (Join-Path $qa ('released-lock-' + $i + '.json')) -Raw | ConvertFrom-Json
            Require ($result.status -ceq 'passed' -and $evidence.first_win32_error -eq 32 -and $evidence.attempts -gt 1) 'Transient sharing violation was not observed and released.'
            Require ((Get-FileHash -LiteralPath $file).Hash -ceq $hash) 'Waiting changed file bytes.'
            $report.checks.Add([ordered]@{ name = 'waits for actual lock release'; iteration = $i; status = 'passed'; attempts = $evidence.attempts; elapsed_ms = $evidence.elapsed_ms })
        } finally {
            if (-not $async.IsCompleted) { $worker.Stop() }
            $worker.Dispose()
            $held.Dispose()
        }
    }
    $report.status = 'passed'
    Write-Host 'PASS immediate readiness, persistent-lock failure and three actual releases; fixture bytes unchanged.'
} catch { $report.status = 'failed'; $report.error_type = $_.Exception.GetType().Name; throw }
finally { $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $qa 'sharing-regression.json') -Encoding utf8NoBOM }
