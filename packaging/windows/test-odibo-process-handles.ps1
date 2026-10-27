<# Isolated OS process-handle regression. No application installation or execution.
   Copies only the runner's existing command interpreter, never publishes it. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$QaDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -cne 'true' -or -not $IsWindows -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted') { throw 'Disposable Windows CI only.' }
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$qa = [IO.Path]::GetFullPath($QaDir)
Require ($qa.StartsWith(([IO.Path]::GetFullPath($env:GITHUB_WORKSPACE).TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) 'QA must stay within the runner workspace.'
[void][IO.Directory]::CreateDirectory($qa)
$root = Join-Path $env:RUNNER_TEMP ('odibo-process-handles-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
$copy = Join-Path $root 'cmd.exe'
$systemCmd = Join-Path $env:SystemRoot 'System32/cmd.exe'
Copy-Item -LiteralPath $systemCmd -Destination $copy
Require ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath $systemCmd).Hash) 'Runner command-interpreter copy differs.'
. (Join-Path $PSScriptRoot 'close-odibo-gui-process.ps1')
function Exclusive-Probe {
    try {
        $stream = [IO.File]::Open($copy, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $stream.Dispose()
        return [ordered]@{ available = $true; hresult = 0 }
    } catch [IO.IOException] { return [ordered]@{ available = $false; hresult = $_.Exception.HResult } }
}
$records = [Collections.Generic.List[object]]::new()
$report = [ordered]@{ status = 'running'; application_executed = $false; command = 'runner-owned cmd.exe /d /c exit 0'; checks = $records }
try {
    for ($iteration = 1; $iteration -le 5; $iteration++) {
        Require ((Exclusive-Probe).available) 'Fresh fixture EXE cannot be opened exclusively.'
        $start = [Diagnostics.ProcessStartInfo]::new($copy)
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
        foreach ($argument in @('/d','/c','exit','0')) { [void]$start.ArgumentList.Add($argument) }
        $process = [Diagnostics.Process]::Start($start)
        $record = [ordered]@{ iteration = $iteration; forced_termination = $false }
        $records.Add($record)
        try {
            Require ($process.WaitForExit(15000)) 'Runner command interpreter did not terminate normally.'
            $record.exit_code = $process.ExitCode
            Require ($process.ExitCode -eq 0) 'Runner command interpreter returned an error.'
            $record.before_handle_release = Exclusive-Probe
            Close-OdiboGuiProcess $process
            $record.after_handle_release = Exclusive-Probe
            # The first diagnostic falsified the proposed lock explanation.
            # Assert the observed ordinary-process contract rather than claim
            # a lock which Windows did not exhibit. Full GUI acceptance remains.
            Require ($record.before_handle_release.available) 'Exited ordinary process unexpectedly retains an exclusive image lock.'
            Require ($record.after_handle_release.available) 'Exclusive access did not return after normal-exit handle release.'
            Write-Host ('PASS ordinary exited process is unlocked before and after handle release: ' + $iteration)
        } finally { $process.Dispose() }
    }
    $report.status = 'passed'
} catch { $report.status = 'failed'; $report.error_type = $_.Exception.GetType().Name; throw }
finally { $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $qa 'process-handles.json') -Encoding utf8NoBOM }
