param(
    [string]$OutputDirectory = "",
    [switch]$SkipInstaller
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
if (!$OutputDirectory) { $OutputDirectory = Join-Path $root 'dist' }
$out = [IO.Path]::GetFullPath($OutputDirectory)
$cache = Join-Path $root '.runtime-build'
$lock = Get-Content (Join-Path $root 'runtime-lock.json') -Raw | ConvertFrom-Json
$project = Join-Path $root 'src/MacDictate.Windows/MacDictate.Windows.csproj'
function Assert-Exit([string]$name) {
    if ($LASTEXITCODE -ne 0) { throw "$name failed: exit $LASTEXITCODE" }
}
New-Item -ItemType Directory -Force $cache, $out | Out-Null
$sourceSHA = (& git -C $root rev-parse HEAD).Trim()
Assert-Exit 'Git source identity'
$dirty = & git -C $root status --porcelain --untracked-files=no
Assert-Exit 'Check source tree'
if ($dirty) { throw 'Commit source changes before building a release artifact' }
$untracked = & git -C $root ls-files --others --exclude-standard windows/src windows/runtime-lock.json windows/global.json
Assert-Exit 'Check untracked build inputs'
if ($untracked) { throw 'Untracked application inputs would break source SHA identity; commit them before release build' }
if (Test-Path (Join-Path $out 'MacDictate')) { throw 'Output app folder already exists; choose a fresh OutputDirectory. Existing files were preserved.' }
if (@(Get-ChildItem $out -File | Where-Object { $_.Name -match '^MacDictate_Windows_v1\.6\.0_x64\.(zip|exe)$' }).Count -gt 0) {
    throw 'Versioned package already exists; choose a fresh OutputDirectory. Existing artifacts were preserved.'
}
$archive = Join-Path $cache 'whisper-source.zip'
if (!(Test-Path $archive) -or (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $lock.whisper.sourceSha256) {
    Invoke-WebRequest $lock.whisper.sourceUrl -OutFile "$archive.part"
    if ((Get-FileHash "$archive.part" -Algorithm SHA256).Hash.ToLowerInvariant() -ne $lock.whisper.sourceSha256) {
        Remove-Item "$archive.part" -Force
        throw 'Whisper source checksum mismatch'
    }
    Move-Item "$archive.part" $archive -Force
}
$source = Join-Path $cache ('whisper.cpp-' + $lock.whisper.commit)
if (!(Test-Path $source)) { Expand-Archive $archive $cache -Force }
$native = Join-Path $cache ('build-' + $lock.whisper.commit)
& cmake -S $source -B $native -A x64 `
    -DBUILD_SHARED_LIBS=OFF -DGGML_STATIC=ON -DGGML_BACKEND_DL=OFF -DGGML_NATIVE=OFF `
    -DGGML_AVX=OFF -DGGML_AVX2=OFF -DGGML_AVX512=OFF -DGGML_FMA=OFF `
    -DGGML_F16C=OFF -DGGML_BMI2=OFF -DGGML_SSE42=OFF -DGGML_OPENMP=OFF `
    -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF -DWHISPER_BUILD_IS_DEV=OFF `
    -DWHISPER_CURL=OFF -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded
Assert-Exit 'CMake configure'
& cmake --build $native --config Release --target whisper-cli --parallel 2
Assert-Exit 'Whisper build'
$app = Join-Path $out 'MacDictate'
Push-Location $root
try {
    & dotnet publish $project -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -o $app
    Assert-Exit 'dotnet publish'
} finally { Pop-Location }
$runtime = Join-Path $app 'runtime'
New-Item -ItemType Directory -Force $runtime | Out-Null
$cli = Join-Path $native 'bin/Release/whisper-cli.exe'
if (!(Test-Path $cli)) { throw "Whisper executable not found: $cli" }
$manifestTool = @(Get-ChildItem (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin/*/x64/mt.exe') | Sort-Object FullName -Descending)[0].FullName
& $manifestTool -manifest (Join-Path $PSScriptRoot 'whisper-utf8.manifest') "-outputresource:$cli;#1"
Assert-Exit 'Embed UTF-8 process code page for native Unicode paths'
$embedded = Join-Path $cache 'whisper-embedded.manifest'
& $manifestTool "-inputresource:$cli;#1" "-out:$embedded"
Assert-Exit 'Read back native manifest'
[xml]$embeddedXml = Get-Content $embedded -Raw
if ($embeddedXml.SelectSingleNode("//*[local-name()='activeCodePage']").InnerText -ne 'UTF-8') { throw 'Native runtime UTF-8 manifest was not embedded' }
Copy-Item $cli $runtime
# Static ggml/whisper + static MSVC CRT; fail rather than silently omit dynamic dependencies.
$dlls = @(Get-ChildItem (Split-Path $cli) -Filter '*.dll')
if ($dlls.Count -gt 0) { throw 'Unexpected DLLs in static Whisper build; inspect packaging dependency closure' }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$visualStudio = (& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
Assert-Exit 'Find MSVC tools'
$dumpbin = @(Get-ChildItem "$visualStudio/VC/Tools/MSVC/*/bin/Hostx64/x64/dumpbin.exe" | Sort-Object FullName -Descending)[0].FullName
$imports = & $dumpbin /dependents $cli
Assert-Exit 'Inspect runtime dependencies'
if (($imports -join "`n") -match '(?im)^\s*(VCRUNTIME\w*|MSVCP\w*|ucrtbase|api-ms-win-crt-[\w-]+)\.dll\s*$') {
    throw 'Whisper requires an unbundled MSVC runtime; static CRT build failed'
}
& (Join-Path $runtime 'whisper-cli.exe') --help 2>&1 | Out-Null
Assert-Exit 'Bundled Whisper launch'
Copy-Item (Join-Path $root 'runtime-lock.json') $app
Copy-Item (Join-Path $root 'README.md') (Join-Path $app 'README.md')
Copy-Item (Join-Path $source 'LICENSE') (Join-Path $app 'WHISPER-LICENSE')
Copy-Item (Join-Path $root 'THIRD-PARTY-NOTICES.md') $app
Copy-Item (Join-Path $root 'licenses') $app -Recurse
$version = (Get-Item (Join-Path $app 'MacDictate.exe')).VersionInfo.ProductVersion.Split('+')[0]
if ($version -ne '1.6.0') { throw "Unexpected app version $version" }
$zip = Join-Path $out "MacDictate_Windows_v$version`_x64.zip"
if (Test-Path $zip) { throw 'Refusing to overwrite an existing versioned ZIP' }
Compress-Archive -Path $app -DestinationPath $zip -CompressionLevel Optimal
if (!$SkipInstaller) {
    $iscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'
    if (!(Test-Path $iscc)) { throw 'Inno Setup 6 is required to build the installer' }
    & $iscc "/DAppSource=$app" "/DOutputDir=$out" (Join-Path $PSScriptRoot 'installer.iss')
    Assert-Exit 'Inno Setup'
}
$packages = @(Get-ChildItem $out -File | Where-Object { $_.Name -match '^MacDictate_Windows_v1\.6\.0_x64\.(zip|exe)$' })
if ($packages.Count -ne $(if ($SkipInstaller) { 1 } else { 2 })) { throw 'Windows package list is incomplete' }
$manifest = [ordered]@{
    schemaVersion = 1; version = '1.6.0'; platform = 'windows-x64'; sourceSHA = $sourceSHA
    runtime = $lock.whisper; model = $lock.model; signed = $false
    artifacts = @($packages | ForEach-Object { [ordered]@{
        name = $_.Name; bytes = $_.Length; sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    } })
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $out 'windows-build-manifest.json') -Encoding utf8
$manifest.artifacts | ForEach-Object { "$($_.sha256)  $($_.name)" } | Set-Content (Join-Path $out 'WINDOWS-SHA256SUMS') -Encoding ascii
Write-Host "Windows distribution built from $sourceSHA"
