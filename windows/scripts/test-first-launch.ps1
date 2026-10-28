param([Parameter(Mandatory)][string]$AppPath, [Parameter(Mandatory)][string]$ReportPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class FirstLaunchWindow {
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint processId);
    [DllImport("user32.dll")] public static extern bool PostThreadMessage(uint thread, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
}
'@
$appProfile = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'MacDictate'
# Do not redirect production settings via a test flag or overwrite any existing profile.
if (Test-Path $appProfile) { throw 'Normal fresh-profile acceptance requires an unused runner user profile; existing data was preserved' }
if (Get-Process MacDictate -ErrorAction SilentlyContinue) { throw 'Another MacDictate process exists; normal acceptance refuses to interfere' }
$checks = [Collections.Generic.List[string]]::new()
$process = $null; $thread = 0; $success = $false; $dpi = 0; $failure = $null
$screenshot = [IO.Path]::ChangeExtension($ReportPath, '.png')
try {
    $process = Start-Process -FilePath $AppPath -PassThru
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 100; $process.Refresh()
        if ($process.HasExited) { throw 'Normal installed launch exited before showing its main window' }
        if ($timer.Elapsed.TotalSeconds -gt 30) { throw 'Normal installed launch did not show a window' }
    } while ($process.MainWindowHandle -eq [IntPtr]::Zero -or ![FirstLaunchWindow]::IsWindowVisible($process.MainWindowHandle))
    $handle = $process.MainWindowHandle
    [uint32]$owner = 0; $thread = [FirstLaunchWindow]::GetWindowThreadProcessId($handle, [ref]$owner)
    $window = [System.Windows.Automation.AutomationElement]::FromHandle($handle)
    $checks.Add('normal production launch shows real first-run window without CLI test mode')
    foreach ($id in @('NextSetupAction', 'StartStopRecording', 'CancelOperation', 'LastDictationText', 'CopyLastDictation')) {
        $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $id)
        $control = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
        if ($null -eq $control) { throw "Installed onboarding control missing: $id" }
        if ($id -eq 'NextSetupAction' -and (!$control.Current.IsEnabled -or $control.Current.Name -notmatch '(?i)model|\u043c\u043e\u0434\u0435\u043b\u044c')) { throw 'Fresh normal launch must offer explicit model setup' }
        if ($id -eq 'StartStopRecording' -and $control.Current.IsEnabled) { throw 'Fresh normal launch must not claim microphone/model readiness' }
        $checks.Add("installed actual onboarding control: $id")
    }
    $dpi = [FirstLaunchWindow]::GetDpiForWindow($handle)
    $bounds = $window.Current.BoundingRectangle
    $bitmap = [Drawing.Bitmap]::new([int]$bounds.Width, [int]$bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen([int]$bounds.X, [int]$bounds.Y, 0, 0, $bitmap.Size); $bitmap.Save($screenshot, [Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
    [void][FirstLaunchWindow]::PostMessage($handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 200
    if ([FirstLaunchWindow]::IsWindowVisible($handle)) { throw 'Closing normal main window did not hide it to tray' }
    $second = Start-Process -FilePath $AppPath -PassThru
    if (!$second.WaitForExit(10000) -or $second.ExitCode -ne 0) { throw 'Second normal launch failed to activate existing instance' }
    $timer.Restart()
    while (![FirstLaunchWindow]::IsWindowVisible($handle)) { if ($timer.Elapsed.TotalSeconds -gt 10) { throw 'Second launch did not reopen the existing main window' }; Start-Sleep -Milliseconds 100 }
    if (@(Get-Process MacDictate -ErrorAction Stop).Count -ne 1) { throw 'Second launch left multiple normal instances' }
    $checks.Add('close-to-tray and normal second launch reopen the same process')
    if (Test-Path (Join-Path $appProfile 'models')) { throw 'Normal fresh launch unexpectedly began model setup without user action' }
    $checks.Add('normal startup does not automatically download a model')
    $success = $true
} catch { $failure = $_.Exception.Message; throw } finally {
    if ($null -ne $process -and !$process.HasExited) {
        if ($thread -ne 0) { [void][FirstLaunchWindow]::PostThreadMessage($thread, 0x0012, [IntPtr]::Zero, [IntPtr]::Zero) }
        if (!$process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
    }
    [ordered]@{ success = $success; scenario = 'installed-normal-fresh-profile'; testMode = $false; checks = @($checks.ToArray()); failure = $failure; screenshots = @([IO.Path]::GetFileName($screenshot)); dpi = $dpi; dpi125 = 'NOT_RUN'; dpi150 = 'NOT_RUN'; microphone = 'real enumeration only; physical capture NOT_RUN'; keyboard = 'real registration; physical Alt NOT_RUN'; physicalWindows10_11 = 'NOT_RUN' } | ConvertTo-Json -Depth 5 | Set-Content $ReportPath -Encoding utf8
}
