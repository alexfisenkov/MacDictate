param([Parameter(Mandatory)][string]$WavePath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
$lock = Get-Content (Join-Path $root 'runtime-lock.json') -Raw | ConvertFrom-Json
$fixture = Join-Path $env:RUNNER_TEMP ('MacDictate кириллица пробел 😀 ' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $fixture | Out-Null
$model = Join-Path $fixture $lock.model.fileName
$wave = Join-Path $fixture 'синтетический голос 🦊.wav'
$report = Join-Path $root 'dist/onboarding-smoke.json'
$previousTemp = $env:TEMP; $previousTmp = $env:TMP
try {
    Copy-Item -LiteralPath $WavePath -Destination $wave
    $waveHash = (Get-FileHash -LiteralPath $wave -Algorithm SHA256).Hash
    Invoke-WebRequest $lock.model.url -OutFile "$model.part"
    if ((Get-Item -LiteralPath "$model.part").Length -ne $lock.model.size -or (Get-FileHash -LiteralPath "$model.part" -Algorithm SHA256).Hash.ToLowerInvariant() -ne $lock.model.sha256) { throw 'Onboarding model size/SHA256 mismatch' }
    Move-Item -LiteralPath "$model.part" -Destination $model
    $env:TEMP = $fixture; $env:TMP = $fixture
    $arguments = @('--onboarding-smoke', '--report', ('"' + $report + '"'), '--model', ('"' + $model + '"'), '--fixture-wave', ('"' + $wave + '"'))
    $process = Start-Process (Join-Path $root 'dist/MacDictate/MacDictate.exe') -ArgumentList $arguments -PassThru
    if (!$process.WaitForExit(480000)) { $process.Kill(); $process.WaitForExit(); throw 'Onboarding UI/ASR acceptance timed out' }
    if (!(Test-Path $report)) { throw 'Onboarding report missing' }
    $result = Get-Content $report -Raw | ConvertFrom-Json
    if ($process.ExitCode -ne 0 -or !$result.success) { throw 'Onboarding acceptance failed; inspect onboarding-smoke.json (synthetic fixture only)' }
    if ($result.scenario -ne 'isolated-onboarding' -or !$result.realWhisper -or !$result.realFixturePhraseMatched -or !$result.syntheticMicrophone -or !$result.syntheticHotkeyActivation) { throw 'Onboarding report must prove real ASR and disclose synthetic capture/hotkey activation' }
    if (!$result.resultVisibleBeforeTestScroll) { throw 'Production recognition left result/Copy below viewport before diagnostic test scrolling; fix the UI before release' }
    if ($result.sources.recognition -ne 'real bundled Whisper' -or $result.sources.microphone -notmatch 'synthetic fixture' -or $result.sources.keyboard -notmatch 'physical Alt NOT_TESTED') { throw 'Onboarding source disclosure mismatch' }
    foreach ($expected in @('01-fresh-ru', '01-download-network', '01-download-integrity', '02-model-saved', '03-microphone-NoDevice', '03-microphone-Silent', '03-microphone-Error', '03-microphone-Signal', '04-hotkey-test', '05-recording', '06-processing', '07-result-before-test-scroll', '07-result-ru', '08-result-en', '09-missing-model', '09-missing-runtime')) {
        $name = 'onboarding-smoke-' + $expected + '.png'
        if ($name -notin $result.screenshots -or !(Test-Path (Join-Path $root "dist/$name"))) { throw "Missing actual UI screenshot: $name" }
    }
    if ((Get-FileHash -LiteralPath $wave -Algorithm SHA256).Hash -ne $waveHash) { throw 'Caller synthetic WAV was modified' }
    if (@(Get-ChildItem -LiteralPath $fixture -Recurse -Filter '*.txt').Count -ne 0) { throw 'Native transcription temporary output was not cleaned up' }
    foreach ($scale in @('1.25', '1.5')) {
        $layoutReport = Join-Path $root ('dist/layout-' + $scale + '-smoke.json')
        # Cheap synthetic recognition only: do not repeat the heavy real Whisper run.
        $process = Start-Process (Join-Path $root 'dist/MacDictate/MacDictate.exe') -ArgumentList @('--onboarding-smoke', '--layout-scale', $scale, '--report', ('"' + $layoutReport + '"')) -PassThru
        if (!$process.WaitForExit(45000)) { $process.Kill(); $process.WaitForExit(); throw "Layout stress $scale timed out" }
        $layout = Get-Content $layoutReport -Raw | ConvertFrom-Json
        if ($process.ExitCode -ne 0 -or !$layout.success -or !$layout.syntheticLayoutStress -or $layout.requestedLayoutScale -ne [double]::Parse($scale, [Globalization.CultureInfo]::InvariantCulture) -or $layout.realWhisper -or $layout.actualDesktopDpi -le 0 -or !$layout.resultVisibleBeforeTestScroll) { throw "Synthetic layout stress $scale failed or misidentified its evidence" }
        foreach ($name in $layout.screenshots) { if (!(Test-Path (Join-Path $root "dist/$name"))) { throw "Layout stress screenshot missing: $name" } }
    }
    Write-Host 'Onboarding UI + one real bundled Whisper invocation PASS; synthetic fixture/capture/key activation; physical Windows10/11 NOT_TESTED.'
} finally {
    $env:TEMP = $previousTemp; $env:TMP = $previousTmp
    # This unique directory contains only this script's generated test inputs.
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
