$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$app = Join-Path $root 'dist/MacDictate/MacDictate.exe'
$report = Join-Path $root 'dist/native-smoke.json'
$stderr = Join-Path $env:RUNNER_TEMP 'macdictate-smoke-stderr.log'
$process = Start-Process $app -ArgumentList @('--smoke-test', '--report', ('"' + $report + '"')) -PassThru -RedirectStandardError $stderr
if (!$process.WaitForExit(45000)) { $process.Kill(); throw 'Native Windows smoke timed out' }
if ($process.ExitCode -ne 0) { Get-Content $stderr; throw "Native smoke failed: exit $($process.ExitCode)" }
$result = Get-Content $report -Raw | ConvertFrom-Json
if (!$result.success) { throw 'Native smoke report does not confirm success' }
Get-Content $report
