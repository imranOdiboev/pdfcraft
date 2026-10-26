param(
    [Parameter(Mandatory)] [string] $PayloadDir,
    [Parameter(Mandatory)] [string] $OutputDir,
    [Parameter(Mandatory)] [string] $ISCC
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or -not $IsWindows) { throw 'Packaging is restricted to a disposable Windows Actions runner.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$payload = (Resolve-Path -LiteralPath $PayloadDir).Path
$output = [IO.Path]::GetFullPath($OutputDir)
$runnerRoot = [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\') + '\'
if (-not $output.StartsWith($runnerRoot, [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)) {
    throw 'Output must be a new directory beneath RUNNER_TEMP.'
}
New-Item -ItemType Directory -Path $output | Out-Null
$versionMatch = [regex]::Match((Get-Content -Raw -LiteralPath (Join-Path $repo 'Cargo.toml')), '(?ms)^\[workspace\.package\]\s*\r?\nversion\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"')
if (-not $versionMatch.Success) { throw 'Expected a numeric Cargo workspace version.' }
$version = $versionMatch.Groups[1].Value
$checkout = (& git -C $repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve checkout SHA.' }
$tree = (& git -C $repo rev-parse 'HEAD^{tree}').Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve checkout tree.' }
$source = $env:ODIBO_SOURCE_SHA
if ($source -cnotmatch '^[a-f0-9]{40}$') { throw 'Missing exact source SHA.' }
$parents = (& git -C $repo rev-list --parents -n 1 HEAD) -split ' '
if ($LASTEXITCODE -ne 0 -or $source -notin $parents) { throw 'Source must be this checkout or a direct parent of the tested PR merge.' }
$build = 0L
if (-not [long]::TryParse($env:GITHUB_RUN_NUMBER, [ref]$build) -or $build -le 0 -or $build -gt [int]::MaxValue) { throw 'Invalid ordered build number.' }
foreach ($name in @('odibo-pdf.exe', 'odibo-pdf-cli.exe')) {
    $exe = Join-Path $payload $name
    $info = (Get-Item -LiteralPath $exe).VersionInfo
    if ($info.ProductName -cne 'ODIBO PDF' -or $info.CompanyName -cne 'IMR4N' -or $info.OriginalFilename -cne $name -or $info.ProductVersion -cne $version) {
        throw "Unexpected executable identity: $name"
    }
    $bytes = [IO.File]::ReadAllBytes($exe)
    if ($bytes.Length -lt 256 -or $bytes[0] -ne 77 -or $bytes[1] -ne 90) { throw 'Invalid PE.' }
    $pe = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($pe -lt 0 -or $pe -gt $bytes.Length - 96 -or [BitConverter]::ToUInt32($bytes, $pe) -ne 0x4550 -or [BitConverter]::ToUInt16($bytes, $pe + 4) -ne 0x8664) { throw 'Expected x64 PE.' }
    $subsystem = if ($name -eq 'odibo-pdf.exe') { 2 } else { 3 }
    if ([BitConverter]::ToUInt16($bytes, $pe + 0x5c) -ne $subsystem) { throw 'Wrong GUI/CLI subsystem.' }
    if ((Get-AuthenticodeSignature -LiteralPath $exe).Status -ne 'NotSigned') { throw 'This candidate workflow requires explicitly unsigned inputs; signing needs its separate reviewed process.' }
    $reported = (& $exe --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $reported -notmatch ('\b' + [regex]::Escape($version) + '\b')) { throw 'Executable version mismatch.' }
}
# Fresh staging, never recursively remove an existing application or user directory.
$installed = Join-Path $output 'installed-payload'
New-Item -ItemType Directory -Path $installed | Out-Null
Get-ChildItem -LiteralPath $payload -Force | Where-Object { $_.Name -notin @('portable.txt', 'SHA256SUMS.txt', 'BUILD_MANIFEST.json', 'BUILD_INFO.txt') } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $installed -Recurse
}
$innoNotices = Join-Path $installed 'licences/installer'
New-Item -ItemType Directory -Path $innoNotices -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'INNO-LICENSE.txt'), (Join-Path $PSScriptRoot 'INNO_SETUP_PROVENANCE.md') -Destination $innoNotices
@("Version: $version", "Build number: $build", "Commit: $checkout", "Source commit: $source", "Tree: $tree", "Run: $env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID", 'Target: x86_64-pc-windows-msvc', 'Unsigned engineering test build; not an official stable release.') | Set-Content -LiteralPath (Join-Path $installed 'BUILD_INFO.txt') -Encoding utf8
$manifestFiles = @(Get-ChildItem -LiteralPath $installed -Recurse -File | Sort-Object FullName | ForEach-Object {
    [ordered]@{path = [IO.Path]::GetRelativePath($installed, $_.FullName).Replace('\','/'); size = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
})
$manifest = [ordered]@{
    schema_version = 1; product = 'ODIBO PDF'; publisher_metadata = 'IMR4N'; version = $version
    build_number = $build; source_sha = $source; checkout_sha = $checkout; checkout_tree = $tree
    repository = $env:GITHUB_REPOSITORY; run_id = $env:GITHUB_RUN_ID; run_attempt = $env:GITHUB_RUN_ATTEMPT
    workflow = $env:GITHUB_WORKFLOW_REF; built_at_utc = [DateTime]::UtcNow.ToString('o')
    target = 'x86_64-pc-windows-msvc'; unsigned = $true; rust = '1.95.0'; installer_compiler = 'Inno Setup 7.1.0 x64'
    files = $manifestFiles
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $installed 'BUILD_MANIFEST.json') -Encoding utf8
function Write-Sums([string] $Directory) {
    Get-ChildItem -LiteralPath $Directory -Recurse -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | Sort-Object FullName | ForEach-Object {
        '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), [IO.Path]::GetRelativePath($Directory, $_.FullName).Replace('\','/')
    } | Set-Content -LiteralPath (Join-Path $Directory 'SHA256SUMS.txt') -Encoding utf8
}
Write-Sums $installed
$verifier = Join-Path $PSScriptRoot 'verify_odibo_payload.py'
& python $verifier $installed --repository $repo --source-sha $source --checkout-sha $checkout --version $version
if ($LASTEXITCODE -ne 0) { throw 'Installed payload verification failed.' }
$deliverables = Join-Path $output 'distribution'
New-Item -ItemType Directory -Path $deliverables | Out-Null
& $ISCC '/Qp' "/DPayloadDir=$installed" "/DOutputDir=$deliverables" "/DAppVersion=$version" "/DBuildNumber=$build" "/DBuildCommit=$source" (Join-Path $PSScriptRoot 'odibo.iss')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
$stem = "ODIBO-PDF-$version-$($source.Substring(0,7))"
$setup = Join-Path $deliverables "$stem-Setup-x64.exe"
if (-not (Test-Path -LiteralPath $setup) -or (Get-AuthenticodeSignature -LiteralPath $setup).Status -ne 'NotSigned') { throw 'Missing explicitly unsigned test Setup.' }
$portable = Join-Path $output 'portable-payload'
Copy-Item -LiteralPath $installed -Destination $portable -Recurse
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'portable.txt') -Destination $portable
Write-Sums $portable
& python $verifier $portable --repository $repo --source-sha $source --checkout-sha $checkout --version $version --portable
if ($LASTEXITCODE -ne 0) { throw 'Portable verification failed.' }
$zip = Join-Path $deliverables "$stem-Portable-x64.zip"
Compress-Archive -Path (Join-Path $portable '*') -DestinationPath $zip -CompressionLevel Optimal
$extracted = Join-Path $output 'verified-archive'
Expand-Archive -LiteralPath $zip -DestinationPath $extracted
& python $verifier $extracted --repository $repo --source-sha $source --checkout-sha $checkout --version $version --portable
if ($LASTEXITCODE -ne 0) { throw 'Actual portable ZIP content verification failed.' }
Copy-Item -LiteralPath (Join-Path $installed 'BUILD_MANIFEST.json') -Destination $deliverables
Write-Sums $deliverables
$size = (Get-ChildItem -LiteralPath $deliverables -File | Measure-Object Length -Sum).Sum
if ($size -gt 200MB) { throw 'Distribution exceeds the 200 MiB free-storage safeguard.' }
# Workflow outputs are paths under the runner-controlled fresh directory, no user input.
@("setup=$setup", "portable=$zip", "payload=$installed", "distribution=$deliverables") | Add-Content -LiteralPath $env:GITHUB_OUTPUT -Encoding utf8
