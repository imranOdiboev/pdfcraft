<#
.SYNOPSIS
  Fetch and verify the pinned compiler on a disposable GitHub Windows runner only.
  This script is never part of the installed application and never runs on the owner's PC.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or [Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
  throw 'Inno compiler preparation is permitted only on a disposable GitHub Actions Windows runner.'
}
if (-not $env:RUNNER_TEMP -or -not (Test-Path -LiteralPath $env:RUNNER_TEMP -PathType Container)) {
  throw 'A valid RUNNER_TEMP is required.'
}
$version = '7.1.0'
$expectedBytes = 14304168L
$expectedSha256 = '0362a383ed217d4c4239b5933866dd96d3eb2102737da92f80f6057a4b40df2f'
$url = 'https://github.com/jrsoftware/issrc/releases/download/is-7_1_0/innosetup-7.1.0-x64.exe'
$runnerRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $env:RUNNER_TEMP).Path)
$toolRoot = [IO.Path]::GetFullPath((Join-Path $runnerRoot ('odibo-inno-' + [Guid]::NewGuid().ToString('N'))))
if (-not $toolRoot.StartsWith($runnerRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Compiler staging directory must remain within RUNNER_TEMP.'
}
New-Item -ItemType Directory -Path $toolRoot | Out-Null
$download = Join-Path $toolRoot 'innosetup-7.1.0-x64.exe'
$compilerDir = Join-Path $toolRoot 'compiler'
Invoke-WebRequest -Uri $url -OutFile $download -MaximumRedirection 5
if ((Get-Item -LiteralPath $download).Length -ne $expectedBytes) { throw 'Inno compiler download size mismatch.' }
if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedSha256) {
  throw 'Inno compiler download SHA-256 mismatch.'
}
$signature = Get-AuthenticodeSignature -LiteralPath $download
if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or
    -not $signature.SignerCertificate -or
    $signature.SignerCertificate.Subject -notmatch '(^|,\s*)CN=Pyrsys B\.V\.(,|$)') {
  throw 'Inno compiler Authenticode verification failed or publisher is unexpected.'
}
# Hash, trusted-chain validation and exact publisher are mandatory before any EXE is run.
$arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/CURRENTUSER',
  ('/DIR="{0}"' -f $compilerDir), ('/LOG="{0}"' -f (Join-Path $toolRoot 'compiler-install.log')))
$process = Start-Process -FilePath $download -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Pinned Inno compiler installation failed ($($process.ExitCode))." }
$compiler = Join-Path $compilerDir 'ISCC.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'Verified Inno installer did not produce ISCC.exe.' }
$compilerVersion = (Get-Item -LiteralPath $compiler).VersionInfo.FileVersion
if ($compilerVersion -notmatch '^7\.1\.0(?:\.0)?$') { throw "Unexpected ISCC version: $compilerVersion" }
$record = [ordered]@{
  compiler = 'Inno Setup'; version = $version; url = $url; sha256 = $expectedSha256
  bytes = $expectedBytes; authenticode = $signature.Status.ToString()
  publisher = $signature.SignerCertificate.Subject
  certificateThumbprint = $signature.SignerCertificate.Thumbprint
  iscc = $compiler; fileVersion = $compilerVersion
}
$record | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $toolRoot 'VERIFIED_COMPILER.json') -Encoding utf8
if (-not $env:GITHUB_OUTPUT -or -not $env:GITHUB_ENV) { throw 'GitHub output files are required.' }
"iscc=$compiler" | Out-File -LiteralPath $env:GITHUB_OUTPUT -Encoding utf8 -Append
"toolchain-provenance=$(Join-Path $toolRoot 'VERIFIED_COMPILER.json')" | Out-File -LiteralPath $env:GITHUB_OUTPUT -Encoding utf8 -Append
"ODIBO_ISCC=$compiler" | Out-File -LiteralPath $env:GITHUB_ENV -Encoding utf8 -Append
Write-Output "Verified Inno Setup $version compiler prepared on the disposable runner."
