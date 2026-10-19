param([Parameter(Mandatory)][string]$WavePath)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$lock = Get-Content (Join-Path $root 'runtime-lock.json') -Raw | ConvertFrom-Json
$testDirectory = Join-Path $env:RUNNER_TEMP ('MacDictate кириллица пробел 😀 ' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $testDirectory | Out-Null
$model = Join-Path $testDirectory $lock.model.fileName
$fixtureWave = Join-Path $testDirectory 'голос 🦊.wav'
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
try {
    Copy-Item -LiteralPath $WavePath -Destination $fixtureWave
    Invoke-WebRequest $lock.model.url -OutFile "$model.part"
    if ((Get-FileHash "$model.part" -Algorithm SHA256).Hash.ToLowerInvariant() -ne $lock.model.sha256) {
        throw 'ASR model SHA256 mismatch'
    }
    if ((Get-Item "$model.part").Length -ne $lock.model.size) { throw 'ASR model size mismatch' }
    Move-Item "$model.part" $model -Force
    $app = Join-Path $root 'dist/MacDictate/MacDictate.exe'
    $report = Join-Path $root 'dist/asr-smoke.json'
    $stderr = Join-Path $env:RUNNER_TEMP 'macdictate-asr-stderr.log'
    $arguments = @('--transcribe', ('"' + $fixtureWave + '"'), '--model', ('"' + $model + '"'), '--report', ('"' + $report + '"'))
    $env:TEMP = $testDirectory
    $env:TMP = $testDirectory
    $process = Start-Process $app -ArgumentList $arguments -PassThru -RedirectStandardError $stderr
    if (!$process.WaitForExit(240000)) { $process.Kill(); throw 'ASR smoke timed out' }
    if ($process.ExitCode -ne 0) { Get-Content $stderr; throw "ASR smoke failed: exit $($process.ExitCode)" }
    $result = Get-Content $report -Raw | ConvertFrom-Json
    if (!$result.success -or $result.text -notmatch '(?i)quick brown fox') { throw 'Synthetic speech did not transcribe the expected phrase' }
    if (@(Get-ChildItem $testDirectory -Filter '*.txt').Count -ne 0) { throw 'Temporary native transcript was not cleaned up' }
    Get-Content $report
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    Remove-Item $model, "$model.part", $fixtureWave -Force -ErrorAction SilentlyContinue
    Remove-Item $testDirectory -ErrorAction SilentlyContinue
}
