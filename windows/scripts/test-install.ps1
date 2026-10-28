$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'release-info.ps1')
$release = Get-WindowsReleaseInfo
$root = Split-Path $PSScriptRoot -Parent
& (Join-Path $root 'tests/test-installed-ui-contract.ps1')
$installer = Join-Path $root ('dist/' + $release.Installer)
$target = Join-Path $env:RUNNER_TEMP ('MacDictate install test ' + [Guid]::NewGuid().ToString('N'))
$appProfile = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'MacDictate'
$owned = @()
function Install-Package {
    $process = Start-Process $installer -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', ('/DIR="' + $target + '"')) -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Installer failed: $($process.ExitCode)" }
}
Install-Package
try {
    $payload = Join-Path $root 'dist/MacDictate'
    $files = @(Get-ChildItem $payload -File -Recurse)
    foreach ($required in @('MacDictate.exe', 'MacDictate.dll', 'MacDictate.Core.dll', 'runtime/whisper-cli.exe', 'runtime-lock.json', 'README.md', 'WHISPER-LICENSE', 'THIRD-PARTY-NOTICES.md', 'legal/eula_oferta.md', 'legal/eula_oferta_en.md', 'legal/privacy_policy.md', 'legal/privacy_policy_en.md', 'licenses/dotnet-LICENSE.md')) {
        if (!(Test-Path (Join-Path $target $required))) { throw "Required installed payload missing: $required" }
    }
    foreach ($file in $files) {
        $relative = [IO.Path]::GetRelativePath($payload, $file.FullName)
        $installed = Join-Path $target $relative
        if (!(Test-Path $installed) -or (Get-FileHash -LiteralPath $installed).Hash -ne (Get-FileHash -LiteralPath $file.FullName).Hash) { throw "Installed bytes differ: $relative" }
    }
    $result = Join-Path $root 'dist/installed-smoke.json'
    $process = Start-Process (Join-Path $target 'MacDictate.exe') -ArgumentList @('--smoke-test', '--report', ('"' + $result + '"')) -PassThru
    if (!$process.WaitForExit(45000)) { $process.Kill(); $process.WaitForExit(); throw 'Installed app native smoke timed out' }
    if ($process.ExitCode -ne 0 -or !(Get-Content $result -Raw | ConvertFrom-Json).success) { throw 'Installed native smoke did not confirm success' }
    # Windows PowerShell supplies the system UIAutomation/.NET Framework assemblies.
    & powershell -NoProfile -File (Join-Path $PSScriptRoot 'test-first-launch.ps1') -AppPath (Join-Path $target 'MacDictate.exe') -ReportPath (Join-Path $root 'dist/installed-first-launch-smoke.json')
    if ($LASTEXITCODE -ne 0) { throw 'Installed normal-profile UI acceptance failed' }
    # Only synthetic sentinels in the just-proven-empty runner profile; no user data.
    $modelDirectory = Join-Path $appProfile 'models'
    New-Item -ItemType Directory -Force $modelDirectory | Out-Null
    $model = Join-Path $modelDirectory 'synthetic-upgrade-model.bin'
    $settings = Join-Path $appProfile 'settings.json'
    $last = Join-Path $appProfile 'last-dictation.txt'
    foreach ($path in @($model, $settings, $last)) { if (Test-Path $path) { throw 'Synthetic upgrade test refuses to overwrite a preexisting profile file' } }
    $owned = @($model, $settings, $last)
    Set-Content $model 'SYNTHETIC preserve this existing model'
    @{ Language = 'ru'; Hotkey = 'DoubleAlt'; ModelPath = $model } | ConvertTo-Json | Set-Content $settings
    Set-Content $last 'SYNTHETIC previous dictation'
    $before = @{}; foreach ($path in $owned) { $before[$path] = (Get-FileHash -LiteralPath $path).Hash }
    Install-Package
    foreach ($path in $owned) { if ((Get-FileHash -LiteralPath $path).Hash -ne $before[$path]) { throw 'Upgrade altered existing settings/model/last text' } }
    $installReport = [ordered]@{ success = $true; scenario = 'installer-payload-upgrade-uninstall'; payloadFilesVerified = $files.Count; version = $release.Version; installedMainWindow = 'fresh blank-state and populated-result UIA/Copy read-back verified by installed-first-launch-smoke.json in normal production mode'; settingsModelsLastText = 'synthetic sentinels preserved byte-for-byte across reinstall'; uninstallPreservation = 'pending' }
} finally {
    $uninstall = Join-Path $target 'unins000.exe'
    if (Test-Path $uninstall) {
        $process = Start-Process $uninstall -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw "Uninstall failed: $($process.ExitCode)" }
    }
}
if (Test-Path (Join-Path $target 'MacDictate.exe')) { throw 'Uninstaller left app executable behind' }
foreach ($path in $owned) { if (!(Test-Path $path) -or (Get-FileHash -LiteralPath $path).Hash -ne $before[$path]) { throw 'Uninstaller changed profile settings/model/last text' } }
$installReport.uninstallPreservation = 'synthetic settings/model/last text retained byte-for-byte'
$installReport | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $root 'dist/installer-smoke.json') -Encoding utf8
# Deliberately retain these synthetic runner-profile files until the runner is recycled.
Write-Host 'Installed payload, normal first-run UI, reinstall and uninstaller preservation PASS.'
