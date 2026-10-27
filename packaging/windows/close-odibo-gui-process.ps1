# Release test-owned administrative resources after proving normal shutdown.
# Closing an exited handle is resource hygiene, not evidence of an image lock.
function Close-OdiboGuiProcess([Diagnostics.Process]$Process, [string]$DiagnosticPath = '', [string]$Role = 'ordinary-process') {
    if (-not $Process.WaitForExit(15000)) { throw 'GUI did not finish normal shutdown.' }
    if ($Process.ExitCode -ne 0) { throw 'GUI returned an error during normal shutdown.' }
    $executable = $Process.StartInfo.FileName
    function Observe-ExclusiveAccess {
        try {
            $stream = [IO.File]::Open($executable, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            $stream.Dispose()
            return [ordered]@{ available = $true; hresult = 0 }
        } catch {
            $errorDetail = $_.Exception.GetBaseException()
            $detail = [ordered]@{ available = $false; hresult = $errorDetail.HResult; error_type = $errorDetail.GetType().Name }
            if (($errorDetail.HResult -band 0x7FFF0000) -eq 0x00070000) { $detail.win32_error = $errorDetail.HResult -band 0xFFFF }
            return $detail
        }
    }
    $evidence = [ordered]@{ normal_exit = $true; exit_code = 0; executable = [IO.Path]::GetFileName($executable); role = $Role; process_id = $Process.Id; exited_at_utc = $Process.ExitTime.ToUniversalTime().ToString('o'); observed_at_utc = [DateTime]::UtcNow.ToString('o'); forced_termination = $false }
    if ($DiagnosticPath) { $evidence.before_handle_release = Observe-ExclusiveAccess }
    $Process.Dispose()
    if ($DiagnosticPath) {
        $evidence.after_handle_release = Observe-ExclusiveAccess
        $evidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $DiagnosticPath -Encoding utf8NoBOM
    }
}
