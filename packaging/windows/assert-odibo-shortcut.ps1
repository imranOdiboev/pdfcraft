# Read-only native Shell shortcut verification, shared by fixture and full acceptance.
# Never activates a link, executes its target, resolves moved files or saves changes.
function Assert-OdiboShortcut {
    param([Parameter(Mandatory)][string]$LinkPath,
          [Parameter(Mandatory)][string]$ExpectedTarget,
          [Parameter(Mandatory)][string]$DiagnosticPath)
    if ($env:GITHUB_ACTIONS -cne 'true' -or -not $IsWindows -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted') { throw 'Disposable Windows CI only.' }
    $link = Get-Item -LiteralPath $LinkPath
    $expected = [IO.Path]::GetFullPath($ExpectedTarget)
    $diagnostic = [ordered]@{ status = 'failed'; reader = 'System.Link.TargetParsingPath' }
    $wscript = $shortcut = $shell = $folder = $item = $null
    function Public-ShortcutPath([string]$Value) {
        # Only paths relevant to this fixture; redact account/workspace/temp roots.
        foreach ($root in @($env:RUNNER_TEMP, $env:GITHUB_WORKSPACE, $env:APPDATA, $env:LOCALAPPDATA, $env:USERPROFILE)) {
            if ($root) { $Value = $Value.Replace($root, '<runner-path>', [StringComparison]::OrdinalIgnoreCase) }
        }
        return $Value
    }
    try {
        $wscript = New-Object -ComObject WScript.Shell
        $shortcut = $wscript.CreateShortcut($link.FullName)
        $legacy = [string]$shortcut.TargetPath
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.NameSpace($link.DirectoryName)
        if ($null -eq $folder) { throw 'Cannot read shortcut folder through native Shell.' }
        $item = $folder.ParseName($link.Name)
        if ($null -eq $item) { throw 'Cannot read shortcut through native Shell.' }
        # Microsoft defines this Unicode property as the target Shell path; for
        # files it is the target ItemPathDisplay. Do not fall back to whichever
        # reader happens to match, or accept a matching basename/hash elsewhere.
        $native = [string]$item.ExtendedProperty('System.Link.TargetParsingPath')
        $diagnostic.expected_target = Public-ShortcutPath $expected
        $diagnostic.legacy_target = Public-ShortcutPath $legacy
        $diagnostic.native_target = Public-ShortcutPath $native
        $diagnostic.legacy_equals_expected = $legacy -and [IO.Path]::GetFullPath($legacy) -ieq $expected
        $diagnostic.native_equals_expected = $native -and [IO.Path]::GetFullPath($native) -ieq $expected
        $diagnostic.target_exists = $native -and [IO.File]::Exists($native)
        $diagnostic.arguments_empty = [string]::IsNullOrEmpty([string]$shortcut.Arguments)
        if (-not $diagnostic.native_equals_expected -or -not $diagnostic.target_exists) { throw 'Start menu shortcut points to another application.' }
        if (-not $diagnostic.arguments_empty) { throw 'Start menu shortcut has unexpected command arguments.' }
        $diagnostic.status = 'passed'
        return [pscustomobject]$diagnostic
    } finally {
        $diagnostic | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $DiagnosticPath -Encoding utf8NoBOM
        foreach ($com in @($item,$folder,$shell,$shortcut,$wscript)) {
            if ($null -ne $com -and [Runtime.InteropServices.Marshal]::IsComObject($com)) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($com) }
        }
    }
}
