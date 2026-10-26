<#
.SYNOPSIS
  Optional genuine installer client-area captures using only the attributed Inter fonts.
.NOTES
  Disposable hosted Windows runner only. Registers existing repository Inter fonts for
  this desktop session, then removes the registration. No font file is installed/copied.
  A PNG is published only when every visible native text control uses an allowed Inter
  font program and that font has a glyph for every visible character. Failure to prove
  this produces a skipped evidence record, never a substitute or edited mockup.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SetupPath,
    [Parameter(Mandatory)][string]$QaDir
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -cne 'true' -or -not $IsWindows -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted') { throw 'Installer capture is restricted to disposable GitHub-hosted Windows runners.' }
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$SetupPath = (Resolve-Path -LiteralPath $SetupPath).Path
$QaDir = [IO.Path]::GetFullPath($QaDir)
$workspacePrefix = [IO.Path]::GetFullPath($env:GITHUB_WORKSPACE).TrimEnd('\') + '\'
if (-not $QaDir.StartsWith($workspacePrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Capture output must stay inside the Actions workspace.' }
[void][IO.Directory]::CreateDirectory($QaDir)
$temporary = Join-Path $env:RUNNER_TEMP ('odibo-installer-capture-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temporary)
$fonts = @('Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf') | ForEach-Object {
    $path = Join-Path $root ('assets/fonts/' + $_)
    [pscustomobject]@{ path = $path; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant(); licence = 'OFL-1.1' }
}
$records = [Collections.Generic.List[object]]::new()
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
# Original test interop with documented Windows GDI/window APIs. No unsafe code or
# product dependency; these declarations are used solely on the disposable CI desktop.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
public static class OdiboInstallerCapture {
    public delegate bool EnumProc(IntPtr window, IntPtr parameter);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceEx(string file, uint flags, IntPtr reserved);
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern bool RemoveFontResourceEx(string file, uint flags, IntPtr reserved);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr window);
    [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr window, IntPtr dc);
    [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr dc, IntPtr value);
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int GetTextFace(IntPtr dc, int count, StringBuilder name);
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern uint GetGlyphIndices(IntPtr dc, string text, int count, [Out] ushort[] glyphs, uint flags);
    [DllImport("gdi32.dll")] public static extern uint GetFontData(IntPtr dc, uint table, uint offset, [Out] byte[] data, uint count);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr window, ref Point point);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int command);
    public static IntPtr[] Children(IntPtr root) {
        var result = new List<IntPtr>();
        EnumChildWindows(root, (window, _) => { result.Add(window); return true; }, IntPtr.Zero);
        return result.ToArray();
    }
    public static string Text(IntPtr window) {
        var text = new StringBuilder(4096);
        GetWindowText(window, text, text.Capacity);
        return text.ToString();
    }
    public static string ProveFont(IntPtr window, string text, string[] allowedHashes) {
        var font = SendMessage(window, 0x0031, IntPtr.Zero, IntPtr.Zero); // WM_GETFONT
        if (font == IntPtr.Zero) throw new InvalidOperationException("A visible native text control did not expose its font.");
        var dc = GetDC(window);
        if (dc == IntPtr.Zero) throw new InvalidOperationException("No text-control device context.");
        var previous = SelectObject(dc, font);
        try {
            var face = new StringBuilder(256);
            if (GetTextFace(dc, face.Capacity, face) == 0 || !face.ToString().StartsWith("Inter", StringComparison.Ordinal))
                throw new InvalidOperationException("Visible native text uses an unapproved or fallback face.");
            var size = GetFontData(dc, 0, 0, null, 0);
            if (size == 0 || size == 0xFFFFFFFF || size > 10000000) throw new InvalidOperationException("Cannot verify the actual Inter font program.");
            var data = new byte[(int)size];
            if (GetFontData(dc, 0, 0, data, size) != size) throw new InvalidOperationException("Cannot read the actual Inter font program.");
            var hash = Convert.ToHexString(SHA256.HashData(data)).ToLowerInvariant();
            if (Array.IndexOf(allowedHashes, hash) < 0) throw new InvalidOperationException("Text-control font program does not match an attributed repository font.");
            // Setup text is BMP EN/RU. Reject missing glyphs instead of letting GDI use
            // a system fallback. Control characters do not themselves render a glyph.
            var visible = new StringBuilder();
            foreach (char character in text) if (!char.IsControl(character)) visible.Append(character);
            var value = visible.ToString();
            var glyphs = new ushort[value.Length];
            if (GetGlyphIndices(dc, value, value.Length, glyphs, 1) == 0xFFFFFFFF) throw new InvalidOperationException("Cannot verify glyph coverage.");
            foreach (var glyph in glyphs) if (glyph == 0xFFFF) throw new InvalidOperationException("Visible setup text would require a fallback glyph.");
            return face + ":" + hash;
        } finally {
            if (previous != IntPtr.Zero) SelectObject(dc, previous);
            ReleaseDC(window, dc);
        }
    }
}
'@

$registered = [Collections.Generic.List[string]]::new()
try {
    foreach ($font in $fonts) {
        if ([OdiboInstallerCapture]::AddFontResourceEx($font.path, 0, [IntPtr]::Zero) -le 0) { throw 'Could not register the attributed Inter font for this temporary desktop session.' }
        $registered.Add($font.path)
    }
    # Notify the desktop about this session-only registration, with no permanent registry entry.
    [void][OdiboInstallerCapture]::SendMessage([IntPtr]0xFFFF, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero)
    $probe = [Drawing.Font]::new('Inter', 9)
    try { if ($probe.Name -cne 'Inter') { throw 'System.Drawing resolved Inter to a fallback family.' } }
    finally { $probe.Dispose() }
    foreach ($language in @('en', 'ru')) {
        $record = [ordered]@{ language = $language; status = 'skipped'; fonts = $fonts; method = 'Real Inno wizard client area, native WM_GETFONT/GetTextFace/GetFontData SHA-256 and glyph coverage checks; OS nonclient chrome excluded.' }
        $process = $null
        $output = Join-Path $QaDir ('windows-setup-' + $language + '.png')
        try {
            if (Test-Path -LiteralPath $output) { throw 'Capture output already exists.' }
            $start = [Diagnostics.ProcessStartInfo]::new($SetupPath)
            $start.UseShellExecute = $false
            $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Normal
            foreach ($argument in @('/CURRENTUSER', '/SP-', '/NORESTART', ('/LANG=' + $language), ('/DIR=' + (Join-Path $temporary ('Never installed ' + $language))))) { [void]$start.ArgumentList.Add($argument) }
            $process = [Diagnostics.Process]::Start($start)
            $owned = [Collections.Generic.HashSet[int]]::new()
            [void]$owned.Add($process.Id)
            $wizard = $null
            $deadline = [DateTime]::UtcNow.AddSeconds(30)
            while ($null -eq $wizard -and -not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
                $snapshot = @(Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId)
                for ($depth = 0; $depth -lt 4; $depth++) {
                    foreach ($entry in $snapshot) { if ($owned.Contains([int]$entry.ParentProcessId)) { [void]$owned.Add([int]$entry.ProcessId) } }
                }
                $windows = [Windows.Automation.AutomationElement]::RootElement.FindAll([Windows.Automation.TreeScope]::Children, [Windows.Automation.Condition]::TrueCondition)
                foreach ($window in $windows) {
                    if ($owned.Contains($window.Current.ProcessId) -and $window.Current.ClassName -ceq 'TWizardForm') { $wizard = $window; break }
                }
                Start-Sleep -Milliseconds 200
            }
            if ($null -eq $wizard) { throw 'Could not identify the actual owned Inno wizard window.' }
            $handle = [IntPtr]$wizard.Current.NativeWindowHandle
            [void][OdiboInstallerCapture]::ShowWindow($handle, 5)
            [void][OdiboInstallerCapture]::SetForegroundWindow($handle)
            Start-Sleep -Milliseconds 500
            $evidence = [Collections.Generic.List[object]]::new()
            $nativeLabels = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($child in [OdiboInstallerCapture]::Children($handle)) {
                if (-not [OdiboInstallerCapture]::IsWindowVisible($child)) { continue }
                $text = [OdiboInstallerCapture]::Text($child)
                if ([string]::IsNullOrWhiteSpace($text)) { continue }
                $proof = [OdiboInstallerCapture]::ProveFont($child, $text, [string[]]@($fonts.sha256))
                $evidence.Add([pscustomobject]@{ text = $text; font = $proof })
                [void]$nativeLabels.Add($text.Replace('&', '').Trim())
            }
            if ($evidence.Count -lt 4) { throw 'Too few visible text controls were verified.' }
            # Fail closed if accessibility exposes visible labels absent from the verified
            # native-control set: a windowless or owner-drawn label is not assumed safe.
            $elements = $wizard.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition)
            foreach ($element in $elements) {
                $current = $element.Current
                if ($current.IsOffscreen -or [string]::IsNullOrWhiteSpace($current.Name)) { continue }
                if ($current.ControlType -in @([Windows.Automation.ControlType]::Text, [Windows.Automation.ControlType]::Button, [Windows.Automation.ControlType]::CheckBox)) {
                    if (-not $nativeLabels.Contains($current.Name.Replace('&', '').Trim())) { throw 'Visible accessible text could not be matched to a verified native font control.' }
                }
            }
            $rect = [OdiboInstallerCapture+Rect]::new()
            $point = [OdiboInstallerCapture+Point]::new()
            if (-not [OdiboInstallerCapture]::GetClientRect($handle, [ref]$rect) -or -not [OdiboInstallerCapture]::ClientToScreen($handle, [ref]$point)) { throw 'Could not determine the installer client area.' }
            $width = $rect.Right - $rect.Left
            $height = $rect.Bottom - $rect.Top
            if ($width -le 0 -or $height -le 0 -or $width -gt 8192 -or $height -gt 8192) { throw 'Unsafe or empty client-area dimensions.' }
            $bitmap = [Drawing.Bitmap]::new($width, $height)
            try {
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                try { $graphics.CopyFromScreen($point.X, $point.Y, 0, 0, [Drawing.Size]::new($width, $height)) }
                finally { $graphics.Dispose() }
                $bitmap.Save($output, [Drawing.Imaging.ImageFormat]::Png)
            } finally { $bitmap.Dispose() }
            $record.status = 'captured'
            $record.file = [IO.Path]::GetFileName($output)
            $record.sha256 = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
            $record.width = $width
            $record.height = $height
            $record.native_text_evidence = $evidence
            $record.source_checkout_sha = $env:GITHUB_SHA
            $record.source_run = 'https://github.com/' + $env:GITHUB_REPOSITORY + '/actions/runs/' + $env:GITHUB_RUN_ID
        } catch {
            $record.reason = $_.Exception.Message
            # Never leave an image whose proof failed; output was created only by this run.
            if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
        } finally {
            if ($null -ne $process) {
                # Capture only, never press Install. Process termination is labelled as
                # cleanup and is not an installer cancellation test.
                if (-not $process.HasExited) { $process.Kill($true); [void]$process.WaitForExit(5000) }
                $process.Dispose()
            }
            $records.Add($record)
        }
    }
} catch {
    $records.Add([ordered]@{ status = 'skipped'; reason = $_.Exception.Message; note = 'No screenshot is supplied without complete font verification.' })
} finally {
    foreach ($font in $registered) { [void][OdiboInstallerCapture]::RemoveFontResourceEx($font, 0, [IntPtr]::Zero) }
    [void][OdiboInstallerCapture]::SendMessage([IntPtr]0xFFFF, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero)
    ConvertTo-Json -InputObject @($records.ToArray()) -Depth 25 | Set-Content -LiteralPath (Join-Path $QaDir 'installer-capture-evidence.json') -Encoding utf8NoBOM
    Copy-Item -LiteralPath (Join-Path $root 'assets/fonts/OFL-Inter.txt') -Destination (Join-Path $QaDir 'OFL-Inter.txt')
    Copy-Item -LiteralPath (Join-Path $root 'assets/odibo/LICENSE-ODIBO-BRAND.txt') -Destination (Join-Path $QaDir 'LICENSE-ODIBO-BRAND.txt')
}
