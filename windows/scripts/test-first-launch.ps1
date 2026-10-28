[CmdletBinding(DefaultParameterSetName = 'Native')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Native')][string]$AppPath,
    [Parameter(Mandatory, ParameterSetName = 'Native')][string]$ReportPath,
    [Parameter(Mandatory, ParameterSetName = 'Contract')][switch]$ContractOnly
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Assert-InstalledUiState {
    param([object]$Snapshot, [ValidateSet('Fresh', 'Populated')][string]$State = 'Fresh', [string]$ExpectedText = '')
    if ($Snapshot.window.id -ne 'MacDictateMainWindow' -or $Snapshot.window.name -ne 'MacDictate' -or $Snapshot.window.type -ne 'ControlType.Window' -or $Snapshot.window.offscreen -or !$Snapshot.window.enabled) { throw 'Normal installed launch must expose the visible MacDictate main window' }
    $required = @('NextSetupAction', 'StartStopRecording', 'CancelOperation', 'OperationStatus', 'MicrophoneStatus')
    if ($State -eq 'Populated') {
        if ([string]::IsNullOrWhiteSpace($ExpectedText)) { throw 'Populated result contract requires a nonblank synthetic expected text' }
        $required += 'LastDictationText', 'CopyLastDictation'
    }
    foreach ($id in $required) {
        $found = @($Snapshot.controls | Where-Object { $_.id -eq $id })
        if ($found.Count -ne 1) { throw "Installed onboarding control missing or ambiguous: $id" }
        $control = $found[0]; $bounds = $control.bounds; $windowBounds = $Snapshot.window.bounds
        if ($control.offscreen -or $bounds.width -le 0 -or $bounds.height -le 0 -or $bounds.x -lt $windowBounds.x -or $bounds.y -lt $windowBounds.y -or ($bounds.x + $bounds.width) -gt ($windowBounds.x + $windowBounds.width) -or ($bounds.y + $bounds.height) -gt ($windowBounds.y + $windowBounds.height)) { throw "Installed onboarding control must be visible inside the window: $id" }
        if ([string]::IsNullOrWhiteSpace($control.name)) { throw "Installed onboarding control has no accessible label: $id" }
        if ($id -in @('NextSetupAction', 'StartStopRecording', 'CancelOperation', 'CopyLastDictation') -and $control.type -ne 'ControlType.Button') { throw "Installed onboarding action must be a button: $id" }
        if ($id -eq 'NextSetupAction' -and (!$control.enabled -or !$control.invokable -or $control.name -notmatch '(?i)model|\u043c\u043e\u0434\u0435\u043b\u044c')) { throw 'Normal launch without a model must offer explicit model setup' }
        if ($id -eq 'StartStopRecording' -and $control.enabled) { throw 'Normal launch without a model must not claim microphone/model readiness' }
        if ($id -eq 'CancelOperation' -and $control.enabled) { throw 'Idle normal launch must not claim an active cancellable operation' }
        if ($id -eq 'LastDictationText' -and ($control.type -ne 'ControlType.Edit' -or $control.value -cne $ExpectedText -or $control.readOnly -ne $true)) { throw 'Installed populated result must expose the exact read-only synthetic text through UI Automation' }
        if ($id -eq 'CopyLastDictation' -and (!$control.enabled -or !$control.invokable)) { throw 'Installed populated result must offer an enabled Copy action' }
    }
    if ($State -eq 'Fresh') {
        # Windows run 40745192074 exposed the old test's invalid assumption:
        # MainForm hides DictationResult while LastText is empty, so UIA omits
        # its children. Absence is valid only here; populated launch needs both.
        foreach ($control in @($Snapshot.controls | Where-Object { $_.id -in @('LastDictationText', 'CopyLastDictation', 'DictationResult') })) {
            if (!$control.offscreen) { throw 'Fresh empty profile must not show a populated result or Copy surface' }
            if ($control.id -eq 'LastDictationText' -and ![string]::IsNullOrEmpty($control.value)) { throw 'Fresh empty profile unexpectedly contains dictation text' }
            if ($control.id -eq 'CopyLastDictation' -and $control.enabled) { throw 'Fresh empty profile must not enable Copy' }
        }
    }
}
if ($ContractOnly) { return }
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing, System.Windows.Forms
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
function Get-UiNode {
    param($Element)
    $current = $Element.Current; $bounds = $current.BoundingRectangle
    $node = [ordered]@{ id = $current.AutomationId; name = $current.Name; type = $current.ControlType.ProgrammaticName; enabled = $current.IsEnabled; offscreen = $current.IsOffscreen; bounds = [ordered]@{ x = $bounds.X; y = $bounds.Y; width = $bounds.Width; height = $bounds.Height }; value = $null; readOnly = $null; invokable = $false }
    $pattern = $null
    $node.invokable = $Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)
    # Only read this script's known synthetic result, never arbitrary inputs.
    if ($node.id -eq 'LastDictationText' -and $Element.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        $value = ([System.Windows.Automation.ValuePattern]$pattern).Current
        $node.value = $value.Value; $node.readOnly = $value.IsReadOnly
    }
    [pscustomobject]$node
}
function Get-InstalledUiSnapshot {
    param($Window, [string]$State)
    $elements = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    $nodes = @(foreach ($element in $elements) { Get-UiNode $element })
    [pscustomobject]@{ state = $State; window = Get-UiNode $Window; controls = $nodes }
}
function Wait-InstalledWindow {
    param($Process)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 100; $Process.Refresh()
        if ($Process.HasExited) { throw 'Normal installed launch exited before showing its main window' }
        if ($timer.Elapsed.TotalSeconds -gt 30) { throw 'Normal installed launch did not show a window' }
    } while ($Process.MainWindowHandle -eq [IntPtr]::Zero -or ![FirstLaunchWindow]::IsWindowVisible($Process.MainWindowHandle))
    if (!$Process.WaitForInputIdle(10000)) { throw 'Normal installed main window did not become idle' }
    $Process.MainWindowHandle
}
function Stop-InstalledProcess {
    param($Process, [uint32]$Thread)
    if ($null -ne $Process -and !$Process.HasExited) {
        if ($Thread -ne 0) { [void][FirstLaunchWindow]::PostThreadMessage($Thread, 0x0012, [IntPtr]::Zero, [IntPtr]::Zero) }
        if (!$Process.WaitForExit(10000)) { $Process.Kill(); $Process.WaitForExit(); throw 'Normal installed process required forced cleanup' }
    }
}
function Save-WindowScreenshot {
    param($Window, [string]$Path)
    $bounds = $Window.Current.BoundingRectangle
    $bitmap = [Drawing.Bitmap]::new([int]$bounds.Width, [int]$bounds.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try { $graphics.CopyFromScreen([int]$bounds.X, [int]$bounds.Y, 0, 0, $bitmap.Size); $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
$appProfile = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'MacDictate'
# Do not redirect production settings via a test flag or overwrite any existing profile.
if (Test-Path $appProfile) { throw 'Normal fresh-profile acceptance requires an unused runner user profile; existing data was preserved' }
if (Get-Process MacDictate -ErrorAction SilentlyContinue) { throw 'Another MacDictate process exists; normal acceptance refuses to interfere' }
$checks = [Collections.Generic.List[string]]::new()
$uiStates = [Collections.Generic.List[object]]::new()
$screenshots = [Collections.Generic.List[string]]::new()
$process = $null; $thread = 0; $success = $false; $dpi = 0; $failure = $null
$screenshot = [IO.Path]::ChangeExtension($ReportPath, '.png')
$syntheticLastPath = Join-Path $appProfile 'last-dictation.txt'
$syntheticText = 'SYNTHETIC installed normal-launch result: The quick brown fox jumps over the lazy dog.'
$ownsSyntheticLast = $false; $clipboardBefore = $null; $clipboardCaptured = $false
try {
    $process = Start-Process -FilePath $AppPath -PassThru
    $handle = Wait-InstalledWindow $process
    [uint32]$owner = 0; $thread = [FirstLaunchWindow]::GetWindowThreadProcessId($handle, [ref]$owner)
    $window = [System.Windows.Automation.AutomationElement]::FromHandle($handle)
    $checks.Add('normal production launch shows real first-run window without CLI test mode')
    $dpi = [FirstLaunchWindow]::GetDpiForWindow($handle)
    Save-WindowScreenshot $window $screenshot; $screenshots.Add([IO.Path]::GetFileName($screenshot))
    $snapshot = Get-InstalledUiSnapshot $window 'fresh-empty'; $uiStates.Add($snapshot)
    Assert-InstalledUiState -Snapshot $snapshot -State Fresh
    $checks.Add('actual UIA hierarchy: visible model setup/status/primary controls; empty result and Copy hidden')
    [void][FirstLaunchWindow]::PostMessage($handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 200
    if ([FirstLaunchWindow]::IsWindowVisible($handle)) { throw 'Closing normal main window did not hide it to tray' }
    $second = Start-Process -FilePath $AppPath -PassThru
    if (!$second.WaitForExit(10000) -or $second.ExitCode -ne 0) { throw 'Second normal launch failed to activate existing instance' }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (![FirstLaunchWindow]::IsWindowVisible($handle)) { if ($timer.Elapsed.TotalSeconds -gt 10) { throw 'Second launch did not reopen the existing main window' }; Start-Sleep -Milliseconds 100 }
    if (@(Get-Process MacDictate -ErrorAction Stop).Count -ne 1) { throw 'Second launch left multiple normal instances' }
    $checks.Add('close-to-tray and normal second launch reopen the same process')
    if (Test-Path (Join-Path $appProfile 'models')) { throw 'Normal fresh launch unexpectedly began model setup without user action' }
    $checks.Add('normal startup does not automatically download a model')
    Stop-InstalledProcess $process $thread
    $process = $null; $thread = 0
    # No test mode or readiness bypass: restart the installed bytes normally,
    # with only a synthetic persisted result in the just-proven-empty profile.
    # The independent onboarding scenario is the real Whisper ASR proof.
    $stream = [IO.File]::Open($syntheticLastPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    $ownsSyntheticLast = $true
    try { $bytes = [Text.Encoding]::UTF8.GetBytes($syntheticText); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    $process = Start-Process -FilePath $AppPath -PassThru
    $handle = Wait-InstalledWindow $process
    $thread = [FirstLaunchWindow]::GetWindowThreadProcessId($handle, [ref]$owner)
    $window = [System.Windows.Automation.AutomationElement]::FromHandle($handle)
    $populatedScreenshot = [IO.Path]::ChangeExtension($ReportPath, $null) + '-populated.png'
    Save-WindowScreenshot $window $populatedScreenshot; $screenshots.Add([IO.Path]::GetFileName($populatedScreenshot))
    $snapshot = Get-InstalledUiSnapshot $window 'synthetic-persisted-result'; $uiStates.Add($snapshot)
    Assert-InstalledUiState -Snapshot $snapshot -State Populated -ExpectedText $syntheticText
    $checks.Add('installed ordinary relaunch exposes exact persisted synthetic text and enabled visible Copy without scrolling')
    $clipboardBefore = [Windows.Forms.Clipboard]::GetDataObject(); $clipboardCaptured = $true
    [Windows.Forms.Clipboard]::SetText('SYNTHETIC Copy action not invoked yet')
    $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::AutomationIdProperty, 'CopyLastDictation')
    $copy = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    ([System.Windows.Automation.InvokePattern]$copy.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
    $timer.Restart()
    while ([Windows.Forms.Clipboard]::GetText() -cne $syntheticText) {
        if ($timer.Elapsed.TotalSeconds -gt 5) { throw 'Installed Copy action did not copy the exact synthetic persisted result' }
        Start-Sleep -Milliseconds 100
    }
    $checks.Add('actual installed Copy invoked through UIA and exact synthetic clipboard text read back')
    if (Test-Path (Join-Path $appProfile 'models')) { throw 'Normal populated launch unexpectedly began model setup without user action' }
    $success = $true
} catch { $failure = $_.Exception.Message; throw } finally {
    try { Stop-InstalledProcess $process $thread } catch { $success = $false; $failure = $_.Exception.Message; throw } finally {
        try {
            if ($ownsSyntheticLast) { Remove-Item -LiteralPath $syntheticLastPath -Force }
            if ($clipboardCaptured) {
                if ($null -eq $clipboardBefore) { [Windows.Forms.Clipboard]::Clear() } else { [Windows.Forms.Clipboard]::SetDataObject($clipboardBefore, $true) }
            }
        } catch { $success = $false; $failure = $_.Exception.Message; throw } finally {
            [ordered]@{ success = $success; scenario = 'installed-normal-fresh-profile'; testMode = $false; checks = @($checks.ToArray()); failure = $failure; screenshots = @($screenshots.ToArray()); uiStates = @($uiStates.ToArray()); resultSource = 'synthetic persisted text, not ASR; real Whisper covered separately by onboarding-smoke.json'; dpi = $dpi; dpi125 = 'NOT_RUN'; dpi150 = 'NOT_RUN'; microphone = 'real enumeration only; physical capture NOT_RUN'; keyboard = 'real registration; physical Alt NOT_RUN'; physicalWindows10_11 = 'NOT_RUN' } | ConvertTo-Json -Depth 8 | Set-Content $ReportPath -Encoding utf8
        }
    }
}
