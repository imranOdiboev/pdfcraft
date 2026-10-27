<# Exact-source inert-payload lifecycle regression, not application acceptance.
   Never execute the fixture payload. Only disposable GitHub-hosted Windows CI. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SetupPath,
    [Parameter(Mandatory)][string]$PayloadDir,
    [Parameter(Mandatory)][string]$WorkRoot,
    [Parameter(Mandatory)][string]$QaDir,
    [switch]$ExpectRegistryRegression
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -cne 'true' -or -not $IsWindows -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted') { throw 'Disposable Windows CI only.' }
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
$root = [IO.Path]::GetFullPath($WorkRoot)
$temp = [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\') + '\'
Require ($root.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -and -not (Test-Path -LiteralPath $root)) 'Requires a fresh runner-temp fixture root.'
$qa = [IO.Path]::GetFullPath($QaDir)
$workspace = [IO.Path]::GetFullPath($env:GITHUB_WORKSPACE).TrimEnd('\') + '\'
Require ($qa.StartsWith($workspace, [StringComparison]::OrdinalIgnoreCase)) 'QA must stay within the runner workspace.'
$setup = (Resolve-Path -LiteralPath $SetupPath).Path
$payload = (Resolve-Path -LiteralPath $PayloadDir).Path
# Prevent confusing the inert fixture with an application build.
Require ([IO.File]::ReadAllText((Join-Path $payload 'odibo-pdf.exe')).StartsWith('Non-executable installer lifecycle fixture, never run as an application.')) 'Expected the explicit inert fixture payload.'
$registry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{A7A4DC1B-3255-4BC6-9F6F-1DA0B61B6524}_is1'
Require (-not (Test-Path -LiteralPath $registry)) 'Refusing to modify a pre-existing registration.'
New-Item -ItemType Directory -Path $root,$qa | Out-Null
$install = Join-Path $root 'Приложение — lifecycle fixture'
$expected = [ordered]@{ ODIBOAppVersion = '0.10.1'; ODIBOBuildNumber = '1'; ODIBOBuildCommit = ('a' * 40) }
$records = [Collections.Generic.List[object]]::new()
$report = [ordered]@{ status = 'running'; inert_payload_only = $true; expected_registry_regression = [bool]$ExpectRegistryRegression; checks = $records }
function Record([string]$Name, $Details) {
    $records.Add([ordered]@{ name = $Name; status = 'passed'; details = $Details })
    Write-Host ('PASS fixture ' + $Name)
}
function Run([string]$File, [string[]]$Arguments, [int]$ExpectedExit = 0) {
    $start = [Diagnostics.ProcessStartInfo]::new($File)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $evidence = [ordered]@{ executable = [IO.Path]::GetFileName($File); timeout_seconds = 60; cleanup_termination = $false; expected_exit = $ExpectedExit }
    try {
        if (-not $process.WaitForExit(60000)) {
            $evidence.cleanup_termination = $true
            $process.Kill($true)
            [void]$process.WaitForExit(5000)
            throw 'Fixture child timed out; termination is failed-test cleanup only.'
        }
        $evidence.exit_code = $process.ExitCode
        Require ($process.ExitCode -eq $ExpectedExit) ('Fixture child returned unexpected exit code: ' + $process.ExitCode)
    } finally {
        $evidence.elapsed_ms = $watch.ElapsedMilliseconds
        $records.Add([ordered]@{ name = 'child process'; details = $evidence })
        $process.Dispose()
    }
}
function Install([string]$Language = 'en', [int]$ExpectedExit = 0) {
    $log = Join-Path $root ([Guid]::NewGuid().ToString('N') + '.log')
    Run $setup @('/CURRENTUSER','/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',('/LANG=' + $Language),('/DIR=' + $install),('/LOG=' + $log)) $ExpectedExit
}
function Read-PublicMetadata {
    Require (Test-Path -LiteralPath $registry) 'Native uninstall registration is missing.'
    $values = Get-ItemProperty -LiteralPath $registry
    Require ($values.DisplayName -ceq 'ODIBO PDF' -and $values.Publisher -ceq 'IMR4N') 'Native product or publisher is incorrect.'
    Require ($values.DisplayVersion -ceq '0.10.1') 'Native display version is incorrect.'
    Require ([IO.Path]::GetFullPath($values.InstallLocation).TrimEnd('\') -ieq $install.TrimEnd('\')) 'Native registration points to another destination.'
    $metadata = [ordered]@{}
    foreach ($name in $expected.Keys) {
        $property = $values.PSObject.Properties[$name]
        $metadata[$name] = if ($null -eq $property) { $null } else { [string]$property.Value }
    }
    return $metadata
}
function Assert-Metadata([string]$Name) {
    $metadata = Read-PublicMetadata
    foreach ($name in $expected.Keys) { Require ($metadata[$name] -ceq $expected[$name]) ('Installed metadata missing or incorrect: ' + $name) }
    foreach ($name in @('odibo-pdf.exe','odibo-pdf-cli.exe')) {
        Require ((Hash (Join-Path $install $name)) -ceq (Hash (Join-Path $payload $name))) 'Installed fixture bytes differ.'
    }
    Record $Name $metadata
}
function Inventory {
    $files = @{}
    foreach ($file in Get-ChildItem -LiteralPath $install -Recurse -File -Force) { $files[[IO.Path]::GetRelativePath($install, $file.FullName)] = Hash $file.FullName }
    return $files
}
function Assert-SameInventory($Before) {
    $after = Inventory
    Require ($after.Count -eq $Before.Count) 'Refused install changed file inventory.'
    foreach ($name in $Before.Keys) { Require ($after.ContainsKey($name) -and $after[$name] -ceq $Before[$name]) 'Refused install changed file bytes.' }
}
function Uninstall {
    Run (Join-Path $install 'unins000.exe') @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
    Require (-not (Test-Path -LiteralPath $registry)) 'Uninstall registration remains.'
    foreach ($name in @('odibo-pdf.exe','odibo-pdf-cli.exe')) { Require (-not (Test-Path -LiteralPath (Join-Path $install $name))) 'Fixture payload remains after uninstall.' }
}
try {
    Install
    if ($ExpectRegistryRegression) {
        $metadata = Read-PublicMetadata
        foreach ($name in $expected.Keys) { Require ($null -eq $metadata[$name]) ('Old registry timing did not reproduce missing field: ' + $name) }
        Record 'negative control: successful native registration erased all three premature custom fields' $metadata
        Uninstall
        Record 'negative-control uninstaller cleaned its own registration and payload' $null
        $report.status = 'observed registry regression; not successful metadata acceptance'
    } else {
        Assert-Metadata 'fresh EN install retains exact build metadata'
        $sentinel = Join-Path $install 'unknown-user-data.txt'
        [IO.File]::WriteAllText($sentinel, 'Synthetic user data must survive reinstall and uninstall.')
        $sentinelHash = Hash $sentinel
        # Even a missing individual field must fail closed without changing files.
        $before = Inventory
        Remove-ItemProperty -LiteralPath $registry -Name 'ODIBOAppVersion'
        try {
            Install 'en' 1
            Assert-SameInventory $before
            Require ($null -eq (Get-ItemProperty -LiteralPath $registry).PSObject.Properties['ODIBOAppVersion']) 'Refused install silently repaired invalid metadata.'
            Record 'invalid installed metadata refused without file changes' $null
        } finally { Set-ItemProperty -LiteralPath $registry -Name 'ODIBOAppVersion' -Value $expected.ODIBOAppVersion }
        Set-ItemProperty -LiteralPath $registry -Name 'ODIBOBuildNumber' -Value '2'
        try {
            Install 'ru' 1
            Assert-SameInventory $before
            Require ((Get-ItemProperty -LiteralPath $registry).ODIBOBuildNumber -ceq '2') 'Refused downgrade changed registered version.'
            Record 'higher-build registry fixture refused without file changes (not historical upgrade)' $null
        } finally { Set-ItemProperty -LiteralPath $registry -Name 'ODIBOBuildNumber' -Value $expected.ODIBOBuildNumber }
        Install 'ru'
        Assert-Metadata 'same-build RU reinstall retains exact build metadata'
        Require ((Hash $sentinel) -ceq $sentinelHash) 'Reinstall changed synthetic user data.'
        Uninstall
        Require ((Hash $sentinel) -ceq $sentinelHash) 'Uninstall changed synthetic user data.'
        Require ([IO.File]::ReadAllText((Join-Path $install '.odibo-install-root')) -ceq '{A7A4DC1B-3255-4BC6-9F6F-1DA0B61B6524}') 'Successful-install identity did not survive uninstall.'
        Record 'uninstall removes registration and executables, preserving unknown user data and identity hint' $null
        Install 'en'
        Assert-Metadata 'same-folder reinstall after removal retains exact build metadata'
        Require ((Hash $sentinel) -ceq $sentinelHash) 'Same-folder reinstall changed synthetic user data.'
        Uninstall
        Require ((Hash $sentinel) -ceq $sentinelHash) 'Final uninstall changed synthetic user data.'
        Record 'final clean uninstall preserves synthetic user data' $null
        $report.status = 'passed'
    }
} catch {
    $report.status = 'failed'
    # Only fixture-specific public metadata and generic exception type are published.
    $report.error_type = $_.Exception.GetType().Name
    throw
} finally {
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $qa 'installer-metadata.json') -Encoding utf8NoBOM
}
