param([string]$BinDir = 'target/x86_64-pc-windows-msvc/release', [string]$QaDir = 'dist/windows-qa')
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $QaDir -Force | Out-Null
$gui = (Resolve-Path (Join-Path $BinDir 'odibo-pdf.exe')).Path
$cli = (Resolve-Path (Join-Path $BinDir 'odibo-pdf-cli.exe')).Path
foreach ($exe in @($gui, $cli)) {
    $info = (Get-Item -LiteralPath $exe).VersionInfo
    if ($info.ProductName -ne 'ODIBO PDF' -or $info.CompanyName -ne 'IMR4N') { throw 'Wrong PE identity' }
    if ($info.OriginalFilename -ne [IO.Path]::GetFileName($exe)) { throw 'Wrong PE filename' }
    $bytes = [IO.File]::ReadAllBytes($exe)
    $pe = [BitConverter]::ToInt32($bytes, 0x3c)
    if ([BitConverter]::ToUInt16($bytes, $pe + 4) -ne 0x8664) { throw 'Not x64' }
}
$ico = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot '../../assets/odibo/odibo-pdf.ico'))
if ([BitConverter]::ToUInt16($ico, 2) -ne 1) { throw 'Not an ICO container' }
$count = [BitConverter]::ToUInt16($ico, 4)
$sizes = @()
for ($i = 0; $i -lt $count; $i++) {
    $entry = 6 + 16 * $i
    $size = if ($ico[$entry] -eq 0) { 256 } else { [int]$ico[$entry] }
    $sizes += $size
    $offset = [BitConverter]::ToUInt32($ico, $entry + 12)
    if ([BitConverter]::ToUInt32($ico, $offset) -ne 0x474e5089) { throw 'ICO entry is not PNG' }
}
foreach ($required in @(16,32,48,256)) { if ($required -notin $sizes) { throw "Missing ICO size $required" } }

# The runner launches only this build with an explicit private control file. No user PDFs.
$env:PDFCRAFT_SYSTEM_FONTS = '0'
foreach ($theme in @('light','dark')) {
    $control = Join-Path $env:RUNNER_TEMP "odibo-ui-$theme.json"
    if (Test-Path -LiteralPath $control) { throw 'Control file already exists' }
    $process = Start-Process -FilePath $gui -ArgumentList @('--new-window','--theme',$theme,'--language','en','--control',('"' + $control + '"')) -WindowStyle Hidden -PassThru
    try {
        $deadline = [DateTime]::UtcNow.AddSeconds(45)
        while (-not (Test-Path -LiteralPath $control)) {
            if ($process.HasExited) { throw "GUI exited before control became available: $($process.ExitCode)" }
            if ([DateTime]::UtcNow -gt $deadline) { throw 'GUI control startup timed out' }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Seconds 2
        & $cli ui --control $control screenshot --out (Join-Path $QaDir "windows-home-$theme.png")
        if ($LASTEXITCODE -ne 0) { throw 'Native Windows screenshot failed' }
        & $cli ui --control $control inspect | Set-Content -LiteralPath (Join-Path $QaDir "windows-home-$theme.json") -Encoding utf8
        if ($LASTEXITCODE -ne 0) { throw 'Native Windows UI inspection failed' }
        if ($process.HasExited) { throw 'GUI stopped unexpectedly' }
        Write-Output "Windows $theme GUI: launched, control inspection and screenshot passed."
    } finally {
        if (-not $process.HasExited) { Stop-Process -InputObject $process }
    }
}
'Automated runner screenshots, not a manual hardware/DPI/printer test. ODIBO graphics: LicenseRef-ODIBO-Brand.' | Set-Content -LiteralPath (Join-Path $QaDir 'README.txt') -Encoding utf8
