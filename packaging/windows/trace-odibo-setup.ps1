<# Read-only observation of a freshly launched real Setup on disposable CI only.
   This probe is NOT cancellation acceptance. Cleanup termination is recorded explicitly.
   No command lines, environment, account names, screenshots or unrelated windows are logged. #>
param([Alias('SetupPath')][string]$ProbeSetupPath, [Alias('QaDir')][string]$ProbeQaDir, [switch]$LibraryOnly)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -cne 'true' -or -not $IsWindows -or $env:RUNNER_ENVIRONMENT -cne 'github-hosted') { throw 'Disposable Windows CI only.' }
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class OdiboSetupTrace {
    public delegate bool Callback(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumWindows(Callback callback, IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, Callback callback, IntPtr data);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr hwnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsChild(IntPtr parent, IntPtr child);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    public static IntPtr[] Windows(IntPtr parent) {
        var result = new List<IntPtr>();
        Callback callback = (hwnd, data) => { result.Add(hwnd); return result.Count < 400; };
        if (parent == IntPtr.Zero) EnumWindows(callback, IntPtr.Zero);
        else EnumChildWindows(parent, callback, IntPtr.Zero);
        return result.ToArray();
    }
    public static string Text(IntPtr hwnd) { var text = new StringBuilder(512); GetWindowText(hwnd, text, 512); return text.ToString(); }
    public static string Class(IntPtr hwnd) { var text = new StringBuilder(128); GetClassName(hwnd, text, 128); return text.ToString(); }
}
'@
function Safe-Label([string]$Value) {
    # Only owned installer labels are inspected; redact paths even in its own labels.
    $value = $Value -replace '(?i)[a-z]:\\[^\r\n]*', '<path>'
    if ($env:USERNAME) { $value = $value.Replace($env:USERNAME, '<account>') }
    return $value
}
function Get-OdiboSetupSnapshot($Owned, [long]$Elapsed) {
    $windows = [Collections.Generic.List[object]]::new()
    foreach ($handle in [OdiboSetupTrace]::Windows([IntPtr]::Zero)) {
        [uint32]$windowProcess = 0
        [void][OdiboSetupTrace]::GetWindowThreadProcessId($handle, [ref]$windowProcess)
        if (-not $Owned.Contains([int]$windowProcess)) { continue }
        $native = @([OdiboSetupTrace]::Windows($handle) | ForEach-Object {
            [ordered]@{ handle=$_.ToInt64(); class=[OdiboSetupTrace]::Class($_); id=[OdiboSetupTrace]::GetDlgCtrlID($_); name=Safe-Label ([OdiboSetupTrace]::Text($_)); visible=[OdiboSetupTrace]::IsWindowVisible($_); enabled=[OdiboSetupTrace]::IsWindowEnabled($_) }
        })
        $elements = [Collections.Generic.List[object]]::new()
        $uiaError = $null
        try {
            $root = [Windows.Automation.AutomationElement]::FromHandle($handle)
            foreach ($element in $root.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition)) {
                if ($elements.Count -ge 300) { break }
                $current = $element.Current
                $elements.Add([ordered]@{ name=Safe-Label $current.Name; type=$current.ControlType.ProgrammaticName; class=$current.ClassName; automation_id=$current.AutomationId; process_id=$current.ProcessId; handle=$current.NativeWindowHandle; enabled=$current.IsEnabled; offscreen=$current.IsOffscreen; patterns=@($element.GetSupportedPatterns() | ForEach-Object ProgrammaticName) })
            }
        } catch { $uiaError = $_.Exception.GetType().Name }
        $windows.Add([ordered]@{ handle=$handle.ToInt64(); process_id=$windowProcess; class=[OdiboSetupTrace]::Class($handle); title=Safe-Label ([OdiboSetupTrace]::Text($handle)); visible=[OdiboSetupTrace]::IsWindowVisible($handle); enabled=[OdiboSetupTrace]::IsWindowEnabled($handle); native=$native; uia=$elements; uia_error=$uiaError })
    }
    return [ordered]@{ elapsed_ms=$Elapsed; windows=$windows }
}
if ($LibraryOnly) { return }
if (-not $ProbeSetupPath -or -not $ProbeQaDir) { throw 'SetupPath and QaDir are required for the observation probe.' }
$records = [Collections.Generic.List[object]]::new()
$owned = [Collections.Generic.HashSet[int]]::new()
$start = [Diagnostics.ProcessStartInfo]::new((Resolve-Path -LiteralPath $ProbeSetupPath).Path)
$start.UseShellExecute = $false
$start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Normal
foreach ($arg in @('/CURRENTUSER', '/SP-', '/NORESTART', ('/DIR=' + (Join-Path $env:RUNNER_TEMP 'ODIBO observation never installed')))) { [void]$start.ArgumentList.Add($arg) }
$process = [Diagnostics.Process]::Start($start)
[void]$owned.Add($process.Id)
$watch = [Diagnostics.Stopwatch]::StartNew()
try {
    for ($sample = 0; $sample -lt 5; $sample++) {
        Start-Sleep -Seconds 2
        $snapshot = @(Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, SessionId, Name)
        do {
            $before = $owned.Count
            foreach ($entry in $snapshot) { if ($owned.Contains([int]$entry.ParentProcessId)) { [void]$owned.Add([int]$entry.ProcessId) } }
        } while ($before -ne $owned.Count)
        $record = Get-OdiboSetupSnapshot $owned $watch.ElapsedMilliseconds
        $record.root_exited = $process.HasExited
        $record.processes = @($snapshot | Where-Object { $owned.Contains([int]$_.ProcessId) })
        $records.Add($record)
    }
} finally {
    $cleanupTermination = -not $process.HasExited
    if ($cleanupTermination) { $process.Kill($true); [void]$process.WaitForExit(5000) }
    New-Item -ItemType Directory -Path $ProbeQaDir -Force | Out-Null
    [ordered]@{ purpose='observation only; NOT a successful cancellation'; user_interactive=[Environment]::UserInteractive; runner_session=[Diagnostics.Process]::GetCurrentProcess().SessionId; cleanup_termination=$cleanupTermination; samples=$records } | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath (Join-Path $ProbeQaDir 'setup-window-trace.json') -Encoding utf8NoBOM
    $process.Dispose()
}
