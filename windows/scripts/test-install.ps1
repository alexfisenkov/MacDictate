$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$installer = Join-Path $root 'dist/MacDictate_Windows_v1.6.0_x64.exe'
$target = Join-Path $env:RUNNER_TEMP ('MacDictate install test ' + [Guid]::NewGuid().ToString('N'))
$process = Start-Process $installer -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', ('/DIR="' + $target + '"')) -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Installer failed: $($process.ExitCode)" }
try {
    foreach ($relative in @('MacDictate.exe', 'runtime/whisper-cli.exe', 'runtime-lock.json', 'WHISPER-LICENSE')) {
        $installed = Join-Path $target $relative
        $original = Join-Path (Join-Path $root 'dist/MacDictate') $relative
        if ((Get-FileHash $installed).Hash -ne (Get-FileHash $original).Hash) { throw "Installed bytes differ: $relative" }
    }
    $result = Join-Path $root 'dist/installed-smoke.json'
    $process = Start-Process (Join-Path $target 'MacDictate.exe') -ArgumentList @('--smoke-test', '--report', ('"' + $result + '"')) -PassThru
    if (!$process.WaitForExit(45000)) { $process.Kill(); throw 'Installed app smoke timed out' }
    if ($process.ExitCode -ne 0) { throw 'Installed app smoke failed' }
    if (!(Get-Content $result -Raw | ConvertFrom-Json).success) { throw 'Installed smoke report does not confirm success' }
} finally {
    $uninstall = Join-Path $target 'unins000.exe'
    if (Test-Path $uninstall) {
        $process = Start-Process $uninstall -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw "Uninstall failed: $($process.ExitCode)" }
    }
}
if (Test-Path (Join-Path $target 'MacDictate.exe')) { throw 'Uninstaller left app executable behind' }
