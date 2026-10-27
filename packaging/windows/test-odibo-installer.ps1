<#
.SYNOPSIS
  Real install / installed-app / reinstall / uninstall acceptance on a disposable runner.
.NOTES
  Never run this script on an owner's computer. Deliberate installation is permitted only
  when both Windows and GITHUB_ACTIONS=true are present. Tokens and setup logs stay in
  RUNNER_TEMP, outside the published QA directory. No user-directory recursive deletion.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SetupPath,
    [Parameter(Mandatory)][string]$PayloadDir,
    [Parameter(Mandatory)][string]$PortableZip,
    [Parameter(Mandatory)][string]$QaDir
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -cne 'true' -or -not $IsWindows -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted') { throw 'Installer acceptance is restricted to disposable GitHub-hosted Windows runners.' }
if (-not $env:RUNNER_TEMP) { throw 'RUNNER_TEMP is required.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Full-Path([string]$Path) { [IO.Path]::GetFullPath($Path) }
function Assert-Beneath([string]$Path, [string]$Parent) {
    $child = Full-Path $Path
    $root = (Full-Path $Parent).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    Assert-True ($child.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) 'Test target escapes its intended temporary root.'
}
function Resolve-File([string]$Path) {
    $full = (Resolve-Path -LiteralPath $Path).Path
    Assert-True ([IO.File]::Exists($full)) 'Expected a regular file.'
    return $full
}
$SetupPath = Resolve-File $SetupPath
$PortableZip = Resolve-File $PortableZip
$PayloadDir = (Resolve-Path -LiteralPath $PayloadDir).Path
$QaDir = Full-Path $QaDir
Assert-Beneath $QaDir $env:GITHUB_WORKSPACE
Assert-True ([IO.Path]::IsPathFullyQualified($SetupPath)) 'Setup path must be absolute.'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $PayloadDir 'portable.txt'))) 'Installed payload must not contain a portable marker.'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $PayloadDir 'ODIBOPDF.portable'))) 'Installed payload must not contain a portable marker.'
$testRoot = Join-Path $env:RUNNER_TEMP ('odibo-installer-qa-' + [Guid]::NewGuid().ToString('N'))
Assert-Beneath $testRoot $env:RUNNER_TEMP
Assert-True (-not (Test-Path -LiteralPath $testRoot)) 'Acceptance requires a fresh temporary directory.'
[void][IO.Directory]::CreateDirectory($testRoot)
[void][IO.Directory]::CreateDirectory($QaDir)
$installDir = Join-Path $testRoot 'Приложение ODIBO PDF'
$portableRoot = Join-Path $testRoot 'Независимая portable версия'
$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{A7A4DC1B-3255-4BC6-9F6F-1DA0B61B6524}_is1'
$hklmPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{A7A4DC1B-3255-4BC6-9F6F-1DA0B61B6524}_is1'
Assert-True (-not (Test-Path -LiteralPath $registryPath)) 'Runner already has this test installer registered; refusing to modify it.'
$initialMachineInstall = Test-Path -LiteralPath $hklmPath
$expectedVersion = '0.10.1'
$manifestPath = Join-Path $PayloadDir 'BUILD_MANIFEST.json'
Assert-True ([IO.File]::Exists($manifestPath)) 'Canonical build manifest is required.'
$manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json -Depth 20
$expectedCommit = [string]$manifest.source_sha
$expectedBuild = [string]$manifest.build_number
$expectedVersion = [string]$manifest.version
$buildInfo = Join-Path $PayloadDir 'BUILD_INFO.txt'
if (Test-Path -LiteralPath $buildInfo) {
    foreach ($line in [IO.File]::ReadAllLines($buildInfo)) {
        if ($line -match '^Source commit:\s*(\S+)\s*$') { Assert-True ($Matches[1] -ceq $expectedCommit) 'Build information and manifest disagree about source commit.' }
        if ($line -match '^Build number:\s*(\d+)\s*$') { Assert-True ($Matches[1] -ceq $expectedBuild) 'Build information and manifest disagree about build number.' }
        if ($line -match '^Version:\s*(\S+)\s*$') { Assert-True ($Matches[1] -ceq $expectedVersion) 'Build information and manifest disagree about version.' }
    }
}
Assert-True ($expectedCommit -cmatch '^[0-9a-f]{40}$') 'Expected build commit must be recorded as a complete SHA.'
Assert-True ($expectedBuild -cmatch '^\d+$') 'Expected build number must be present.'
$checks = [Collections.Generic.List[object]]::new()
$guiProcesses = [Collections.Generic.List[Diagnostics.Process]]::new()
$report = [ordered]@{
    status = 'running'
    operating_system = (Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture, OperatingSystemSKU)
    token_is_administrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    standard_user_proven = $false
    source_commit = $expectedCommit
    version = $expectedVersion
    build_number = $expectedBuild
    setup_sha256 = Hash $SetupPath
    portable_sha256 = Hash $PortableZip
    checks = $checks
    manual_required = @('clean Windows 10 x64', 'clean Windows 11 x64', 'standard account and real UAC', 'wizard Cancel and in-progress cancellation/rollback', 'historical previous-version Setup upgrade (none has previously been distributed)', 'physical 100/150/200% DPI', 'SmartScreen and Defender behaviour on downloaded unsigned packages')
    upgrade_evidence = 'Same-build reinstall and registry-only higher-build refusal fixture. No older executable is fabricated or claimed as a previous-version upgrade.'
}
function Passed([string]$Name, $Details = $null) { $checks.Add([pscustomobject]@{ name = $Name; status = 'passed'; details = $Details }); Write-Output ('PASS ' + $Name) }

function Run-Process([string]$File, [string[]]$Arguments, [int]$TimeoutSeconds = 180, [switch]$ExpectFailure) {
    $start = [Diagnostics.ProcessStartInfo]::new($File)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            # Diagnose only this launch tree before failed-test cleanup, never command
            # lines, stdout/control tokens or unrelated desktop windows. A timeout fails.
            try {
                . (Join-Path $PSScriptRoot 'trace-odibo-setup.ps1') -LibraryOnly
                $owned = [Collections.Generic.HashSet[int]]::new()
                [void]$owned.Add($process.Id)
                $snapshot = @(Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, SessionId, Name)
                do {
                    $before = $owned.Count
                    foreach ($entry in $snapshot) { if ($owned.Contains([int]$entry.ParentProcessId)) { [void]$owned.Add([int]$entry.ProcessId) } }
                } while ($owned.Count -ne $before)
                $diagnostic = Get-OdiboSetupSnapshot $owned ($TimeoutSeconds * 1000L)
                $diagnostic.processes = @($snapshot | Where-Object { $owned.Contains([int]$_.ProcessId) })
                $diagnostic.executable = [IO.Path]::GetFileName($File)
                $diagnostic.status = 'failed timeout; cleanup is not a passing operation'
                $diagnostic | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $QaDir ('child-timeout-' + [Guid]::NewGuid().ToString('N') + '.json')) -Encoding utf8NoBOM
            } catch { Write-Host ('Owned-child timeout diagnostic unavailable: ' + $_.Exception.GetType().Name) }
            $process.Kill($true)
            [void]$process.WaitForExit(5000)
            throw ('Acceptance child process timed out: ' + [IO.Path]::GetFileName($File))
        }
        $result = [pscustomobject]@{ ExitCode = $process.ExitCode; Out = $stdout.GetAwaiter().GetResult(); Error = $stderr.GetAwaiter().GetResult() }
        if ($ExpectFailure) { Assert-True ($result.ExitCode -ne 0) 'A refused operation unexpectedly succeeded.' }
        elseif ($result.ExitCode -ne 0) { throw ('Acceptance child failed with exit ' + $result.ExitCode + ': ' + $result.Error) }
        return $result
    } finally { $process.Dispose() }
}
function Run-Setup([string]$Destination, [switch]$ExpectFailure) {
    Assert-Beneath $Destination $testRoot
    $log = Join-Path $testRoot ('setup-' + [Guid]::NewGuid().ToString('N') + '.log')
    return Run-Process $SetupPath @('/CURRENTUSER', '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', ('/DIR=' + $Destination), ('/LOG=' + $log)) -ExpectFailure:$ExpectFailure
}
function Assert-Payload([string]$Destination) {
    $expectedPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in Get-ChildItem -LiteralPath $PayloadDir -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($PayloadDir, $file.FullName)
        [void]$expectedPaths.Add($relative)
        $target = Join-Path $Destination $relative
        Assert-True ([IO.File]::Exists($target)) ('Installed payload file missing: ' + $relative)
        Assert-True ((Hash $target) -ceq (Hash $file.FullName)) ('Installed payload file changed: ' + $relative)
    }
    foreach ($file in Get-ChildItem -LiteralPath $Destination -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($Destination, $file.FullName)
        Assert-True ($expectedPaths.Contains($relative) -or $relative -cmatch '^unins[0-9]{3}\.(exe|dat|msg)$' -or $relative -ceq '.odibo-install-root' -or $relative -ceq 'Сохранённый пользователем документ.pdf') ('Unexpected installed file: ' + $relative)
    }
    foreach ($required in @('odibo-pdf.exe', 'odibo-pdf-cli.exe', 'LICENSE-MIT', 'LICENSE-APACHE', 'NOTICE', 'ATTRIBUTION.toml', 'ATTRIBUTION.md', 'BUILD_INFO.txt', 'BUILD_MANIFEST.json', 'licences/assets/odibo/LICENSE-ODIBO-BRAND.txt')) {
        Assert-True ([IO.File]::Exists((Join-Path $Destination $required))) ('Required installed notice or executable missing: ' + $required)
    }
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $Destination 'models') -Filter '*.rten' -File).Count -ge 2) 'OCR models missing after installation.'
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $Destination 'models') -Filter '*.LICENCE.txt' -File).Count -ge 2) 'OCR model licences missing after installation.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Destination 'portable.txt'))) 'Setup installed a portable marker.'
    foreach ($name in @('odibo-pdf.exe', 'odibo-pdf-cli.exe')) {
        $info = (Get-Item -LiteralPath (Join-Path $Destination $name)).VersionInfo
        Assert-True ($info.ProductName -ceq 'ODIBO PDF' -and $info.CompanyName -ceq 'IMR4N') 'Wrong installed PE publisher or product.'
        Assert-True ($info.ProductVersion -cin @($expectedVersion, ($expectedVersion + '.0'))) 'Wrong installed executable version.'
    }
    $properties = Get-ItemProperty -LiteralPath $registryPath
    foreach ($name in @('ODIBOAppVersion', 'ODIBOBuildNumber', 'ODIBOBuildCommit')) {
        Assert-True ($null -ne $properties.PSObject.Properties[$name]) ('Installed build metadata is missing: ' + $name)
    }
    Assert-True ($properties.DisplayName.StartsWith('ODIBO PDF', [StringComparison]::Ordinal)) 'Wrong installed-programs name.'
    Assert-True ($properties.Publisher -ceq 'IMR4N') 'Wrong installed-programs publisher.'
    Assert-True ($properties.ODIBOAppVersion -ceq $expectedVersion) 'Wrong registered version.'
    Assert-True ([string]$properties.ODIBOBuildNumber -ceq $expectedBuild) 'Wrong registered build number.'
    Assert-True ($properties.ODIBOBuildCommit -ceq $expectedCommit) 'Wrong registered source commit.'
    Assert-True ((Test-Path -LiteralPath $hklmPath) -eq $initialMachineInstall) 'Per-user setup changed machine uninstall registration.'
    $programs = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
    $links = @(Get-ChildItem -LiteralPath $programs -Filter '*.lnk' -Recurse -File | Where-Object { $_.BaseName -ceq 'ODIBO PDF' })
    Assert-True ($links.Count -eq 1) 'Expected exactly one per-user ODIBO PDF Start menu shortcut.'
    $shell = New-Object -ComObject WScript.Shell
    try { Assert-True ((Full-Path $shell.CreateShortcut($links[0].FullName).TargetPath) -ieq (Full-Path (Join-Path $Destination 'odibo-pdf.exe'))) 'Start menu shortcut points to another application.' }
    finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
}
function Assert-NoBackgroundRegistration {
    $services = @(Get-CimInstance Win32_Service | Where-Object { $_.Name -match '(?i)odibo' -or $_.PathName -like ('*' + $installDir + '*') })
    Assert-True ($services.Count -eq 0) 'Setup registered an unexpected service.'
    $tasks = @(Get-ScheduledTask | Where-Object {
        $_.TaskName -match '(?i)odibo' -or @($_.Actions | Where-Object {
            $execute = $_.PSObject.Properties['Execute']
            $null -ne $execute -and [string]$execute.Value -like ('*' + $installDir + '*')
        }).Count -gt 0
    })
    Assert-True ($tasks.Count -eq 0) 'Setup registered an unexpected scheduled task.'
    foreach ($runKey in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')) {
        if (Test-Path -LiteralPath $runKey) {
            $values = Get-ItemProperty -LiteralPath $runKey
            foreach ($property in $values.PSObject.Properties) {
                if ($property.Name -notmatch '^PS') { Assert-True ($property.Name -notmatch '(?i)odibo' -and [string]$property.Value -notlike ('*' + $installDir + '*')) 'Setup registered autorun.' }
            }
        }
    }
    $started = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith(($installDir + '\'), [StringComparison]::OrdinalIgnoreCase) })
    Assert-True ($started.Count -eq 0) 'Setup automatically launched an executable.'
}
function Find-Settings {
    $found = @()
    foreach ($base in @([Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData), [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData))) {
        $folder = Join-Path $base 'ODIBO PDF'
        if (Test-Path -LiteralPath $folder) { $found += @(Get-ChildItem -LiteralPath $folder -Filter 'app.ron' -File -Recurse | Select-Object -ExpandProperty FullName) }
    }
    $found = @($found | Sort-Object -Unique)
    Assert-True ($found.Count -eq 1) 'Could not identify exactly one real Windows installed-app preference file.'
    return $found[0]
}
function Start-Gui([string]$Folder, [string[]]$Options = @()) {
    $control = Join-Path $testRoot ('control-' + [Guid]::NewGuid().ToString('N') + '.json')
    $start = [Diagnostics.ProcessStartInfo]::new((Join-Path $Folder 'odibo-pdf.exe'))
    $start.UseShellExecute = $false
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.Environment['PDFCRAFT_SYSTEM_FONTS'] = '0'
    foreach ($argument in @('--new-window', '--control', $control) + $Options) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    $guiProcesses.Add($process)
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    while (-not [IO.File]::Exists($control)) {
        Assert-True (-not $process.HasExited) 'Installed GUI exited before becoming ready.'
        Assert-True ([DateTime]::UtcNow -lt $deadline) 'Installed GUI startup timed out.'
        Start-Sleep -Milliseconds 250
    }
    return [pscustomobject]@{ Process = $process; Control = $control; Cli = Join-Path $Folder 'odibo-pdf-cli.exe' }
}
function Ui($Session, [string[]]$Arguments) {
    $result = Run-Process $Session.Cli (@('ui', '--control', $Session.Control) + $Arguments) -TimeoutSeconds 60
    return $result.Out | ConvertFrom-Json -Depth 30
}
function Stop-Gui($Session) {
    $quit = Ui $Session @('quit')
    Assert-True ($quit.quitting -eq $true) 'Clean GUI quit unexpectedly requires confirmation.'
    Assert-True ($Session.Process.WaitForExit(15000)) 'GUI did not finish normal shutdown.'
    Assert-True ($Session.Process.ExitCode -eq 0) 'GUI returned an error during normal shutdown.'
    if (Test-Path -LiteralPath $Session.Control) { Remove-Item -LiteralPath $Session.Control -Force }
}
function Assert-UiPreferences($Session, [string]$Language, [string]$Theme) {
    $state = Ui $Session @('state')
    Assert-True ($state.language -ceq $Language) 'Saved GUI language did not load.'
    Assert-True ($state.theme -ieq $Theme) 'Saved GUI theme did not load.'
    return $state
}
function Uninstall {
    $uninstallers = @(Get-ChildItem -LiteralPath $installDir -Filter 'unins*.exe' -File)
    Assert-True ($uninstallers.Count -eq 1) 'Expected one registered Inno uninstaller.'
    [void](Run-Process $uninstallers[0].FullName @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'))
    Assert-True (-not (Test-Path -LiteralPath $registryPath)) 'Uninstall registration remains.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $installDir 'odibo-pdf.exe'))) 'GUI remains after uninstall.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $installDir 'odibo-pdf-cli.exe'))) 'CLI remains after uninstall.'
    foreach ($file in Get-ChildItem -LiteralPath $PayloadDir -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($PayloadDir, $file.FullName)
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $installDir $relative))) ('Installed payload remains after uninstall: ' + $relative)
    }
    $programs = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
    $links = @(Get-ChildItem -LiteralPath $programs -Filter 'ODIBO PDF.lnk' -Recurse -File)
    Assert-True ($links.Count -eq 0) 'Start menu shortcut remains after uninstall.'
}
function Test-WizardCancellation {
    # The same mandatory real-button test also runs against the exact-source fixture.
    # No process termination or manual-required fallback is counted as cancellation.
    $result = & (Join-Path $PSScriptRoot 'test-odibo-setup-cancel.ps1') `
        -SetupPath $SetupPath -CancelRoot (Join-Path $testRoot 'Отменённые установки') `
        -QaDir (Join-Path $QaDir 'cancellation') -Iterations 3
    Assert-True ($result.status -ceq 'passed' -and $result.passed -eq 9) 'All nine real cancellation scenarios must pass.'
    Passed 'real wizard Cancel before installation, three repetitions in language selection, EN and RU' $result
}

try {
    Test-WizardCancellation
    $blockedDir = Join-Path $testRoot 'Portable нельзя обновлять установщиком'
    [void][IO.Directory]::CreateDirectory($blockedDir)
    [IO.File]::WriteAllText((Join-Path $blockedDir 'portable.txt'), 'CI-only portable destination fixture')
    [void](Run-Setup $blockedDir -ExpectFailure)
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $blockedDir 'odibo-pdf.exe'))) 'Setup wrote into a portable directory.'
    Assert-True (-not (Test-Path -LiteralPath $registryPath)) 'Refused portable destination registered the application.'
    Passed 'unregistered portable destination refused safely'
    [void](Run-Setup $installDir)
    Assert-Payload $installDir
    Assert-NoBackgroundRegistration
    Passed 'real per-user installation, exact payload, publisher, version, commit, shortcut, no auto-start/service/task'
    $pdf = & (Join-Path $PSScriptRoot 'test-installed-pdf.ps1') -InstallDir $installDir -PayloadDir $PayloadDir -WorkDir (Join-Path $testRoot 'Документы и проверки')
    Passed 'explicit installed CLI PDF acceptance' $pdf

    $workingPdf = Join-Path $testRoot 'GUI рабочая копия.pdf'
    Copy-Item -LiteralPath $pdf.document -Destination $workingPdf
    $session = Start-Gui $installDir @('--theme', 'dark', '--language', 'ru')
    [void](Ui $session @('set', 'key=theme', 'value=dark'))
    [void](Ui $session @('set', 'key=language', 'value=ru'))
    [void](Assert-UiPreferences $session 'ru' 'dark')
    [void](Ui $session @('open', ('path=' + $workingPdf)))
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    do {
        $state = Ui $session @('state')
        Assert-True ([DateTime]::UtcNow -lt $deadline) 'Installed GUI failed to open and rasterize the test PDF.'
        Start-Sleep -Milliseconds 200
    } until (@($state.documents).Count -eq 1 -and @($state.pending_opens).Count -eq 0 -and ($state.active.raster_memory.page_bytes -gt 0 -or $state.active.raster_memory.tile_bytes -gt 0))
    Assert-True ($state.documents[0].pages -eq 5 -and @($state.active.page_errors).Count -eq 0) 'Installed GUI page open/render failed.'
    [void](Ui $session @('command', 'id=page.rotate'))
    [void](Ui $session @('command', 'id=edit.undo'))
    [void](Ui $session @('command', 'id=edit.redo'))
    $state = Ui $session @('state')
    Assert-True ($state.documents[0].dirty -eq $true) 'Installed GUI edit/Undo/Redo did not produce a modified document.'
    $beforeSave = Hash $workingPdf
    [void](Ui $session @('command', 'id=file.save'))
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do { $state = Ui $session @('state'); Assert-True ([DateTime]::UtcNow -lt $deadline) 'Installed GUI save did not complete.'; Start-Sleep -Milliseconds 200 } until ($state.documents[0].dirty -eq $false)
    [void](Ui $session @('screenshot', '--out', (Join-Path $QaDir 'windows-installed-editor-ru-dark.png')))
    Assert-True ((Hash $workingPdf) -cne $beforeSave) 'GUI save did not modify the disposable working PDF.'
    $savedWorkingHash = Hash $workingPdf
    [void](Run-Process (Join-Path $installDir 'odibo-pdf-cli.exe') @('info', $workingPdf))
    $state | ConvertTo-Json -Depth 25 | Set-Content -LiteralPath (Join-Path $QaDir 'windows-installed-editor-state.json') -Encoding utf8NoBOM
    [void](Ui $session @('command', 'id=page.rotate'))
    [void](Run-Setup $installDir -ExpectFailure)
    Assert-True (-not $session.Process.HasExited) 'Setup closed a running editor.'
    $stillOpen = Ui $session @('state')
    Assert-True ($stillOpen.documents[0].dirty -eq $true) 'Refused setup lost the unsaved document state.'
    Assert-True ((Hash $workingPdf) -ceq $savedWorkingHash) 'Refused setup replaced the working PDF.'
    [void](Ui $session @('command', 'id=edit.undo'))
    Passed 'setup refuses running editor without closing it or losing unsaved changes'
    Stop-Gui $session
    $settings = Find-Settings
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $installDir 'ODIBOPDFData'))) 'Installed GUI unexpectedly used portable data.'
    Passed 'installed native GUI PDF open, raster, rotate, Undo/Redo, save and normal exit'

    $markerName = 'm40-qa-' + [Guid]::NewGuid().ToString('N')
    $localData = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) 'ODIBO PDF'
    $sentinels = [Collections.Generic.List[object]]::new()
    foreach ($relative in @('Recovery', 'Digital IDs')) {
        $folder = Join-Path $localData $relative
        [void][IO.Directory]::CreateDirectory($folder)
        $path = Join-Path $folder ($markerName + '.sentinel')
        Assert-True (-not (Test-Path -LiteralPath $path)) 'Sentinel already exists.'
        [IO.File]::WriteAllText($path, 'Synthetic QA sentinel; not a recovery PDF or certificate.')
        $sentinels.Add([pscustomobject]@{ path = $path; sha256 = Hash $path })
    }
    $unknownDocument = Join-Path $installDir 'Сохранённый пользователем документ.pdf'
    Copy-Item -LiteralPath $pdf.source_documents[0] -Destination $unknownDocument
    $sentinels.Add([pscustomobject]@{ path = $unknownDocument; sha256 = Hash $unknownDocument })
    $settingsHash = Hash $settings
    [void](Run-Setup $installDir)
    Assert-Payload $installDir
    Assert-True ((Hash $settings) -ceq $settingsHash) 'Reinstall modified settings before app launch.'
    foreach ($sentinel in $sentinels) { Assert-True ((Hash $sentinel.path) -ceq $sentinel.sha256) 'Reinstall damaged a user-data marker.' }
    Passed 'same-build reinstall preserves settings, recovery and digital-ID markers and unknown PDF'

    # This is explicitly a registry-only fixture, not a fabricated old/new binary or upgrade.
    $oldBuild = (Get-ItemProperty -LiteralPath $registryPath).ODIBOBuildNumber
    try {
        Set-ItemProperty -LiteralPath $registryPath -Name ODIBOBuildNumber -Value '2147483646'
        [void](Run-Setup $installDir -ExpectFailure)
        Assert-True ((Hash (Join-Path $installDir 'odibo-pdf.exe')) -ceq (Hash (Join-Path $PayloadDir 'odibo-pdf.exe'))) 'Downgrade refusal changed the installed executable.'
    } finally { Set-ItemProperty -LiteralPath $registryPath -Name ODIBOBuildNumber -Value $oldBuild }
    Passed 'higher-build registry fixture refuses downgrade without replacing installed EXE'

    [void][IO.Directory]::CreateDirectory($portableRoot)
    Expand-Archive -LiteralPath $PortableZip -DestinationPath $portableRoot
    $portableExes = @(Get-ChildItem -LiteralPath $portableRoot -Filter 'odibo-pdf.exe' -Recurse -File)
    Assert-True ($portableExes.Count -eq 1) 'Expected one portable GUI in ZIP.'
    $portableDir = $portableExes[0].DirectoryName
    Assert-True ([IO.File]::Exists((Join-Path $portableDir 'portable.txt'))) 'ZIP lacks its portable marker.'
    $portable = Start-Gui $portableDir @('--theme', 'light', '--language', 'en')
    [void](Ui $portable @('set', 'key=theme', 'value=light'))
    [void](Ui $portable @('set', 'key=language', 'value=en'))
    [void](Assert-UiPreferences $portable 'en' 'light')
    Stop-Gui $portable
    $portableSettings = Join-Path $portableDir 'ODIBOPDFData/app.ron'
    Assert-True ([IO.File]::Exists($portableSettings)) 'Portable settings were not written beside the EXE.'
    $portableSettingsHash = Hash $portableSettings
    $session = Start-Gui $installDir
    [void](Assert-UiPreferences $session 'ru' 'dark')
    Stop-Gui $session
    Assert-True ((Hash $portableSettings) -ceq $portableSettingsHash) 'Installed app changed portable settings.'
    Passed 'portable EN/light and installed RU/dark settings remain isolated after normal restart'

    $settingsHash = Hash $settings
    Uninstall
    Assert-True ((Hash $settings) -ceq $settingsHash) 'Uninstall changed saved user preferences.'
    foreach ($sentinel in $sentinels) { Assert-True ((Hash $sentinel.path) -ceq $sentinel.sha256) 'Uninstall removed or changed user data.' }
    Assert-True ((Hash $portableSettings) -ceq $portableSettingsHash) 'Uninstall changed portable settings.'
    Assert-True ([IO.File]::Exists((Join-Path $portableDir 'odibo-pdf.exe'))) 'Uninstall removed portable program.'
    $ownershipMarker = Join-Path $installDir '.odibo-install-root'
    Assert-True ([IO.File]::Exists($ownershipMarker)) 'Uninstall should retain the narrow installation-identity marker for safe same-path reinstall.'
    Assert-True ([IO.File]::ReadAllText($ownershipMarker) -ceq '{A7A4DC1B-3255-4BC6-9F6F-1DA0B61B6524}') 'Unexpected installation-identity marker.'
    Passed 'real uninstall removes application and preserves unknown PDF, settings, data markers and portable copy'

    [void](Run-Setup $installDir)
    Assert-Payload $installDir
    $session = Start-Gui $installDir
    [void](Assert-UiPreferences $session 'ru' 'dark')
    Stop-Gui $session
    foreach ($sentinel in $sentinels) { Assert-True ((Hash $sentinel.path) -ceq $sentinel.sha256) 'Reinstall after uninstall changed user data.' }
    Passed 'same-path reinstall after uninstall restores working app and previous preferences while preserving unknown PDF'
    Uninstall
    for ($i = 0; $i -lt $pdf.source_documents.Count; $i++) {
        Assert-True ((Hash $pdf.source_documents[$i]) -ceq $pdf.source_sha256[$i]) 'An original PDF changed during install/GUI/uninstall acceptance.'
    }
    $report.status = 'passed'
} catch {
    $report.status = 'failed'
    $report.error = $_.Exception.Message
    throw
} finally {
    # Only child processes created here. A forced cleanup is never counted as clean exit.
    foreach ($process in $guiProcesses) {
        try { if (-not $process.HasExited) { $process.Kill($true); [void]$process.WaitForExit(5000) } }
        finally { $process.Dispose() }
    }
    $report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $QaDir 'installer-acceptance.json') -Encoding utf8NoBOM
    $terms = Join-Path $PayloadDir 'licences/assets/odibo/LICENSE-ODIBO-BRAND.txt'
    if (Test-Path -LiteralPath $terms) { Copy-Item -LiteralPath $terms -Destination (Join-Path $QaDir 'LICENSE-ODIBO-BRAND.txt') }
    'Actual installed native egui capture on a GitHub Windows runner. No system fonts: PDFCRAFT_SYSTEM_FONTS=0. Synthetic PDF only; ODIBO marks retain LicenseRef-ODIBO-Brand. Hosted runner checks do not prove clean Windows 10/11 or standard-user/UAC acceptance. Control files and setup logs are intentionally not published.' | Set-Content -LiteralPath (Join-Path $QaDir 'README.txt') -Encoding utf8NoBOM
}
