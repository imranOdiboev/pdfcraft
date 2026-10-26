<#
.SYNOPSIS
  Exercise the explicitly installed CLI with small contributor-original PDF fixtures.
.NOTES
  Runs only on disposable Windows GitHub runners. No private documents, embedded font
  programs, external oracle installation, network access or application installation.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InstallDir,
    [Parameter(Mandatory)][string]$PayloadDir,
    [Parameter(Mandatory)][string]$WorkDir
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -cne 'true' -or -not $IsWindows -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted') { throw 'This acceptance script is restricted to disposable GitHub-hosted Windows runners.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Full-Path([string]$Path) { [IO.Path]::GetFullPath($Path) }
function Assert-Beneath([string]$Path, [string]$Parent) {
    $child = Full-Path $Path
    $root = (Full-Path $Parent).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    Assert-True ($child.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) 'Acceptance work must be strictly inside RUNNER_TEMP.'
}
Assert-Beneath $WorkDir $env:RUNNER_TEMP
Assert-True (-not (Test-Path -LiteralPath $WorkDir)) 'PDF acceptance requires a fresh work directory.'
[void][IO.Directory]::CreateDirectory($WorkDir)
$cli = (Resolve-Path -LiteralPath (Join-Path $InstallDir 'odibo-pdf-cli.exe')).Path
$payloadCli = (Resolve-Path -LiteralPath (Join-Path $PayloadDir 'odibo-pdf-cli.exe')).Path
Assert-True ((Full-Path $cli) -ine (Full-Path $payloadCli)) 'Acceptance must execute the installed CLI, not the staged CLI.'
Assert-True ((Hash $cli) -ceq (Hash $payloadCli)) 'Installed CLI differs from the verified payload.'

function Run-Cli([string[]]$Arguments, [switch]$ExpectFailure) {
    $start = [Diagnostics.ProcessStartInfo]::new($cli)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WorkingDirectory = $WorkDir
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) { $process.Kill($true); throw 'Installed CLI timed out.' }
        $result = [pscustomobject]@{ ExitCode = $process.ExitCode; Out = $stdout.GetAwaiter().GetResult(); Error = $stderr.GetAwaiter().GetResult() }
        if ($ExpectFailure) { Assert-True ($result.ExitCode -ne 0) 'An invalid operation unexpectedly succeeded.' }
        elseif ($result.ExitCode -ne 0) { throw ('Installed CLI failed: ' + $result.Error) }
        return $result
    } finally { $process.Dispose() }
}

function Write-Fixture([string]$Path, [string[]]$Labels) {
    # Standard-14 font NAME only, no font program or third-party document. Synthetic labels.
    $objects = [Collections.Generic.List[string]]::new()
    $objects.Add('<< /Type /Catalog /Pages 2 0 R >>')
    $kids = (0..($Labels.Count - 1) | ForEach-Object { '{0} 0 R' -f (4 + 2 * $_) }) -join ' '
    $objects.Add(('<< /Type /Pages /Kids [{0}] /Count {1} /MediaBox [0 0 200 300] >>' -f $kids, $Labels.Count))
    $objects.Add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    for ($i = 0; $i -lt $Labels.Count; $i++) {
        Assert-True ($Labels[$i] -cmatch '^[A-Z]+-[0-9]+$') 'Only literal synthetic ASCII labels are supported.'
        $objects.Add(('<< /Type /Page /Parent 2 0 R /Contents {0} 0 R /Resources << /Font << /F1 3 0 R >> >> >>' -f (5 + 2 * $i)))
        $stream = 'BT /F1 20 Tf 20 150 Td (' + $Labels[$i] + ') Tj ET'
        $objects.Add(('<< /Length {0} >>' -f [Text.Encoding]::ASCII.GetByteCount($stream)) + "`nstream`n" + $stream + "`nendstream")
    }
    $body = [Text.StringBuilder]::new("%PDF-1.4`n")
    $offsets = [Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $objects.Count; $i++) {
        $offsets.Add([Text.Encoding]::ASCII.GetByteCount($body.ToString()))
        [void]$body.AppendFormat("{0} 0 obj`n{1}`nendobj`n", ($i + 1), $objects[$i])
    }
    $xref = [Text.Encoding]::ASCII.GetByteCount($body.ToString())
    [void]$body.AppendFormat("xref`n0 {0}`n0000000000 65535 f `n", ($objects.Count + 1))
    foreach ($offset in $offsets) { [void]$body.AppendFormat("{0:0000000000} 00000 n `n", $offset) }
    [void]$body.AppendFormat("trailer`n<< /Size {0} /Root 1 0 R >>`nstartxref`n{1}`n%%EOF`n", ($objects.Count + 1), $xref)
    [IO.File]::WriteAllBytes($Path, [Text.Encoding]::ASCII.GetBytes($body.ToString()))
}

function Verify-Pdf([string]$Path, [string[]]$Labels) {
    $info = (Run-Cli @('info', $Path)).Out | ConvertFrom-Json
    Assert-True ($info.pages -eq $Labels.Count) 'Incorrect installed-CLI page count.'
    $text = (Run-Cli @('text', $Path)).Out
    $actual = @([regex]::Matches($text, '(?:LEFT|RIGHT)-[0-9]+') | ForEach-Object { $_.Value })
    Assert-True (($actual -join ',') -ceq ($Labels -join ',')) 'Incorrect installed-CLI page order.'
}

$left = Join-Path $WorkDir 'Левый документ.pdf'
$right = Join-Path $WorkDir 'Правый документ.pdf'
Write-Fixture $left @('LEFT-1', 'LEFT-2')
Write-Fixture $right @('RIGHT-1', 'RIGHT-2', 'RIGHT-3')
$leftHash = Hash $left
$rightHash = Hash $right
Verify-Pdf $left @('LEFT-1', 'LEFT-2')
Verify-Pdf $right @('RIGHT-1', 'RIGHT-2', 'RIGHT-3')
$merged = Join-Path $WorkDir 'Объединённый документ.pdf'
$all = @('LEFT-1', 'LEFT-2', 'RIGHT-1', 'RIGHT-2', 'RIGHT-3')
[void](Run-Cli @('combine', $left, $right, '--out', $merged))
Verify-Pdf $merged $all
$saved = Join-Path $WorkDir 'Сохранённая копия.pdf'
$steps = @(
    @{ tool = 'doc_open'; args = @{ path = 'Объединённый документ.pdf' } },
    @{ tool = 'doc_set_info'; args = @{ doc = 1; key = 'Title'; value = 'Installed application round trip' } },
    @{ tool = 'doc_save'; args = @{ doc = 1; path = 'Сохранённая копия.pdf' } },
    @{ tool = 'doc_close'; args = @{ doc = 1 } },
    @{ tool = 'doc_open'; args = @{ path = 'Сохранённая копия.pdf' } },
    @{ tool = 'page_render'; args = @{ doc = 2; page = 1; dpi = 72 }; out = 'preview.png' }
)
$scriptPath = Join-Path $WorkDir 'steps.json'
$steps | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $scriptPath -Encoding utf8NoBOM
[void](Run-Cli @('run', '--script', $scriptPath, '--root', $WorkDir, '--report'))
Verify-Pdf $saved $all
$png = [IO.File]::ReadAllBytes((Join-Path $WorkDir 'preview.png'))
Assert-True ($png.Length -gt 200 -and [Convert]::ToHexString($png[0..7]) -ceq '89504E470D0A1A0A') 'Installed CLI did not render a real PNG.'
$partsDir = Join-Path $WorkDir 'Части документа'
[void](Run-Cli @('split', $saved, '--every', '2', '--out-dir', $partsDir))
$parts = @(Get-ChildItem -LiteralPath $partsDir -File | Sort-Object Name)
Assert-True ($parts.Count -eq 3) 'Split did not create three expected parts.'
Verify-Pdf $parts[0].FullName @('LEFT-1', 'LEFT-2')
Verify-Pdf $parts[1].FullName @('RIGHT-1', 'RIGHT-2')
Verify-Pdf $parts[2].FullName @('RIGHT-3')
$damaged = Join-Path $WorkDir 'Повреждённый.pdf'
[IO.File]::WriteAllText($damaged, 'This is not a PDF.')
[void](Run-Cli @('info', $damaged) -ExpectFailure)
$rejected = Join-Path $WorkDir 'rejected.pdf'
[void](Run-Cli @('extract', $left, '--pages', '99', '--out', $rejected) -ExpectFailure)
Assert-True (-not (Test-Path -LiteralPath $rejected)) 'Rejected extraction created a document.'
$blocked = Join-Path $WorkDir 'blocked'
[IO.File]::WriteAllText($blocked, 'SENTINEL')
$steps = @(
    @{ tool = 'doc_open'; args = @{ path = 'Левый документ.pdf' } },
    @{ tool = 'doc_set_info'; args = @{ doc = 1; key = 'Title'; value = 'Must remain unsaved' } },
    @{ tool = 'doc_save'; args = @{ doc = 1; path = 'blocked/out.pdf' } }
)
$steps | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $scriptPath -Encoding utf8NoBOM
[void](Run-Cli @('run', '--script', $scriptPath, '--root', $WorkDir) -ExpectFailure)
Assert-True ([IO.File]::ReadAllText($blocked) -ceq 'SENTINEL') 'Failed save changed the destination sentinel.'
Assert-True ((Hash $left) -ceq $leftHash -and (Hash $right) -ceq $rightHash) 'An original PDF changed.'

[pscustomobject]@{
    status = 'passed'
    executable = $cli
    executable_sha256 = Hash $cli
    scenarios = @('open', 'combine', 'page-order', 'save-reopen', 'render', 'split', 'cyrillic-paths', 'invalid-pdf', 'invalid-pages', 'failed-save', 'originals-preserved')
    document = $saved
    source_documents = @($left, $right)
    source_sha256 = @($leftHash, $rightHash)
    synthetic_only = $true
}
