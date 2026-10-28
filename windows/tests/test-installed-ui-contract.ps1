$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# Portable examples for the same contract fed by real UI Automation in the
# installed-launch test. These examples are not Windows runtime evidence.
. (Join-Path $PSScriptRoot '../scripts/test-first-launch.ps1') -ContractOnly

function New-Control {
    param([string]$Id, [string]$Name, [bool]$Enabled, [string]$Type = 'ControlType.Button', [int]$Y = 100)
    [pscustomobject]@{
        id = $Id; name = $Name; enabled = $Enabled; offscreen = $false; type = $Type
        bounds = [pscustomobject]@{ x = 30; y = $Y; width = 300; height = 32 }
        value = $null; readOnly = $null; invokable = $Type -eq 'ControlType.Button'
    }
}
function New-Snapshot {
    [pscustomobject]@{
        window = [pscustomobject]@{ id = 'MacDictateMainWindow'; name = 'MacDictate'; type = 'ControlType.Window'; enabled = $true; offscreen = $false; bounds = [pscustomobject]@{ x = 10; y = 10; width = 650; height = 680 } }
        controls = @(
            New-Control 'NextSetupAction' 'Start setup: download model' $true
            New-Control 'StartStopRecording' 'Start recording' $false -Y 600
            New-Control 'CancelOperation' 'Cancel' $false -Y 640
            New-Control 'OperationStatus' 'MacDictate - ready for the next action' $true 'ControlType.Text' -Y 30
            New-Control 'MicrophoneStatus' 'No input device. Connect a microphone and refresh inputs.' $true 'ControlType.Text' -Y 65
        )
    }
}

$syntheticText = 'SYNTHETIC expected installed result'
function New-PopulatedSnapshot {
    $snapshot = New-Snapshot
    $result = New-Control 'LastDictationText' 'Last dictation' $true 'ControlType.Edit' -Y 480
    $result.value = $syntheticText; $result.readOnly = $true
    $snapshot.controls += $result, (New-Control 'CopyLastDictation' 'Copy text' $true -Y 550)
    $snapshot
}
function Assert-Rejected {
    param([string]$Name, [scriptblock]$Change, [string]$Message, [ValidateSet('Fresh', 'Populated')][string]$State = 'Fresh')
    $snapshot = if ($State -eq 'Fresh') { New-Snapshot } else { New-PopulatedSnapshot }
    & $Change $snapshot
    $rejected = $false
    try { Assert-InstalledUiState -Snapshot $snapshot -State $State -ExpectedText $syntheticText }
    catch {
        if ($_.Exception.Message -notlike ('*' + $Message + '*')) { throw "Unexpected rejection for ${Name}: $($_.Exception.Message)" }
        $rejected = $true
    }
    if (!$rejected) { throw "Broken UI contract was accepted: $Name" }
    $script:passed++
}
$passed = 0
Assert-InstalledUiState -Snapshot (New-Snapshot) -State Fresh; $passed++
Assert-InstalledUiState -Snapshot (New-PopulatedSnapshot) -State Populated -ExpectedText $syntheticText; $passed++
$hidden = New-PopulatedSnapshot
foreach ($control in $hidden.controls | Where-Object { $_.id -in @('LastDictationText', 'CopyLastDictation') }) { $control.offscreen = $true; $control.value = ''; $control.enabled = $false }
Assert-InstalledUiState -Snapshot $hidden -State Fresh; $passed++
$russian = New-Snapshot
$russian.controls[0].name = [regex]::Unescape('\u0421\u043a\u0430\u0447\u0430\u0442\u044c \u043c\u043e\u0434\u0435\u043b\u044c')
Assert-InstalledUiState -Snapshot $russian -State Fresh; $passed++

Assert-Rejected 'missing setup' { param($s) $s.controls = @($s.controls | Where-Object id -ne 'NextSetupAction') } 'missing or ambiguous: NextSetupAction'
Assert-Rejected 'wrong visible window' { param($s) $s.window.id = 'UnexpectedDialog' } 'visible MacDictate main window'
Assert-Rejected 'hidden window' { param($s) $s.window.offscreen = $true } 'visible MacDictate main window'
Assert-Rejected 'disabled setup' { param($s) $s.controls[0].enabled = $false } 'must offer explicit model setup'
Assert-Rejected 'setup without action' { param($s) $s.controls[0].invokable = $false } 'must offer explicit model setup'
Assert-Rejected 'wrong next step' { param($s) $s.controls[0].name = 'Start recording' } 'must offer explicit model setup'
Assert-Rejected 'offscreen setup' { param($s) $s.controls[0].offscreen = $true } 'must be visible inside the window: NextSetupAction'
Assert-Rejected 'clipped setup' { param($s) $s.controls[0].bounds.y = 680 } 'must be visible inside the window: NextSetupAction'
Assert-Rejected 'zero-size setup' { param($s) $s.controls[0].bounds.width = 0 } 'must be visible inside the window: NextSetupAction'
Assert-Rejected 'not a setup button' { param($s) $s.controls[0].type = 'ControlType.Text' } 'must be a button: NextSetupAction'
Assert-Rejected 'premature recording readiness' { param($s) $s.controls[1].enabled = $true } 'must not claim microphone/model readiness'
Assert-Rejected 'premature cancellable activity' { param($s) $s.controls[2].enabled = $true } 'must not claim an active cancellable operation'
Assert-Rejected 'missing visible status' { param($s) $s.controls = @($s.controls | Where-Object id -ne 'OperationStatus') } 'missing or ambiguous: OperationStatus'
Assert-Rejected 'missing microphone guidance' { param($s) $s.controls = @($s.controls | Where-Object id -ne 'MicrophoneStatus') } 'missing or ambiguous: MicrophoneStatus'
Assert-Rejected 'unlabelled guidance' { param($s) $s.controls[4].name = '' } 'no accessible label: MicrophoneStatus'
Assert-Rejected 'duplicate setup' { param($s) $s.controls += $s.controls[0] } 'missing or ambiguous: NextSetupAction'
Assert-Rejected 'premature empty result surface' { param($s) $s.controls += New-Control 'LastDictationText' 'Last dictation' $true 'ControlType.Edit' } 'must not show a populated result or Copy'
Assert-Rejected 'premature Copy surface' { param($s) $s.controls += New-Control 'CopyLastDictation' 'Copy text' $true } 'must not show a populated result or Copy'
Assert-Rejected 'hidden stale text' {
    param($s)
    $node = New-Control 'LastDictationText' 'Last dictation' $true 'ControlType.Edit'; $node.offscreen = $true; $node.value = 'SYNTHETIC unexpected stale text'; $s.controls += $node
} 'unexpectedly contains dictation text'
Assert-Rejected 'hidden but enabled Copy' {
    param($s)
    $node = New-Control 'CopyLastDictation' 'Copy text' $true; $node.offscreen = $true; $s.controls += $node
} 'must not enable Copy'
Assert-Rejected 'populated missing result' { param($s) $s.controls = @($s.controls | Where-Object id -ne 'LastDictationText') } 'missing or ambiguous: LastDictationText' Populated
Assert-Rejected 'populated missing Copy' { param($s) $s.controls = @($s.controls | Where-Object id -ne 'CopyLastDictation') } 'missing or ambiguous: CopyLastDictation' Populated
Assert-Rejected 'populated wrong text' { param($s) $s.controls[5].value = 'SYNTHETIC wrong text' } 'exact read-only synthetic text' Populated
Assert-Rejected 'populated empty text' { param($s) $s.controls[5].value = '' } 'exact read-only synthetic text' Populated
Assert-Rejected 'populated editable result' { param($s) $s.controls[5].readOnly = $false } 'exact read-only synthetic text' Populated
Assert-Rejected 'populated result without ValuePattern' { param($s) $s.controls[5].value = $null; $s.controls[5].readOnly = $null } 'exact read-only synthetic text' Populated
Assert-Rejected 'populated hidden result' { param($s) $s.controls[5].offscreen = $true } 'must be visible inside the window: LastDictationText' Populated
Assert-Rejected 'populated clipped Copy' { param($s) $s.controls[6].bounds.y = 680 } 'must be visible inside the window: CopyLastDictation' Populated
Assert-Rejected 'populated disabled Copy' { param($s) $s.controls[6].enabled = $false } 'must offer an enabled Copy action' Populated
Assert-Rejected 'populated noninvokable Copy' { param($s) $s.controls[6].invokable = $false } 'must offer an enabled Copy action' Populated
Write-Host "Installed UI snapshot contract: $passed PASS (portable synthetic examples; native UIA still required)."
