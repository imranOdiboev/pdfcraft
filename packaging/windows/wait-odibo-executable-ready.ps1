# Synchronize the acceptance test with Windows releasing an exited executable.
# No file bytes are modified; a persistent lock or other error fails the test.
function Wait-OdiboExecutableReady {
    param([Parameter(Mandatory)][string]$Path,
          [ValidateRange(50,15000)][int]$TimeoutMilliseconds = 15000,
          [string]$DiagnosticPath = '')
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $evidence = [ordered]@{ status = 'failed'; executable = [IO.Path]::GetFileName($Path); timeout_ms = $TimeoutMilliseconds; attempts = 0; first_win32_error = $null; last_win32_error = $null }
    try {
        do {
            if ($watch.ElapsedMilliseconds -ge $TimeoutMilliseconds) { throw 'Executable remained in use after normal shutdown.' }
            $evidence.attempts++
            $available = $false
            try {
                $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
                $stream.Dispose()
                $available = $true
            } catch {
                $problem = $_.Exception.GetBaseException()
                $win32 = if (($problem.HResult -band 0x7FFF0000) -eq 0x00070000) { $problem.HResult -band 0xFFFF } else { $null }
                if ($null -eq $evidence.first_win32_error) { $evidence.first_win32_error = $win32 }
                $evidence.last_win32_error = $win32
                if ($win32 -notin @(32,33)) { throw 'Executable could not be checked for exclusive access after normal shutdown.' }
            }
            if ($watch.ElapsedMilliseconds -ge $TimeoutMilliseconds) { throw 'Executable remained in use after normal shutdown.' }
            if ($available) {
                $evidence.status = 'passed'
                return [pscustomobject]$evidence
            }
            Start-Sleep -Milliseconds ([Math]::Min(50, [Math]::Max(1, $TimeoutMilliseconds - $watch.ElapsedMilliseconds)))
        } while ($true)
    } finally {
        $evidence.elapsed_ms = $watch.ElapsedMilliseconds
        if ($DiagnosticPath) { $evidence | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $DiagnosticPath -Encoding utf8NoBOM }
    }
}
