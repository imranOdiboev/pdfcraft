# Bounded, read-only evidence for exactly the two executables in this CI fixture.
# No command lines, environment variables, full paths or unrelated processes.
function Get-OdiboExecutableObservation([string]$Folder) {
    $processes = @(Get-CimInstance Win32_Process -Filter "Name='odibo-pdf.exe' OR Name='odibo-pdf-cli.exe'" | Select-Object ProcessId,ParentProcessId,SessionId,Name,ExecutablePath)
    $observations = @()
    foreach ($name in @('odibo-pdf.exe','odibo-pdf-cli.exe')) {
        $path = [IO.Path]::GetFullPath((Join-Path $Folder $name))
        $entry = [ordered]@{ executable = $name; exists = [IO.File]::Exists($path); matching_processes = @() }
        $entry.matching_processes = @($processes | Where-Object { $_.ExecutablePath -and [IO.Path]::GetFullPath($_.ExecutablePath) -ieq $path } | Select-Object -First 8 ProcessId,ParentProcessId,SessionId,Name)
        if ($entry.exists) {
            $entry.attributes = [string][IO.File]::GetAttributes($path)
            try {
                $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
                $stream.Dispose()
                $entry.exclusive_access = $true
            } catch {
                $errorDetail = $_.Exception.GetBaseException()
                $entry.exclusive_access = $false
                $entry.error_type = $errorDetail.GetType().Name
                $entry.hresult = $errorDetail.HResult
                if (($errorDetail.HResult -band 0x7FFF0000) -eq 0x00070000) { $entry.win32_error = $errorDetail.HResult -band 0xFFFF }
            }
        }
        $observations += $entry
    }
    return $observations
}
