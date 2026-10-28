$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release-info.ps1')
$release = Get-WindowsReleaseInfo
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('macdictate-package-guards-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $fixture 'scripts') | Out-Null
try {
    Copy-Item (Join-Path $PSScriptRoot 'build.ps1') (Join-Path $fixture 'scripts')
    Copy-Item (Join-Path $PSScriptRoot 'release-info.ps1') (Join-Path $fixture 'scripts')
    $projectDirectory = Join-Path $fixture 'src/MacDictate.Windows'
    New-Item -ItemType Directory -Force $projectDirectory | Out-Null
    Copy-Item (Join-Path (Split-Path $PSScriptRoot -Parent) 'src/MacDictate.Windows/MacDictate.Windows.csproj') $projectDirectory
    Copy-Item (Join-Path (Split-Path $PSScriptRoot -Parent) 'runtime-lock.json') $fixture
    Set-Content (Join-Path $fixture '.gitignore') "dist/`n.runtime-build/"
    & git -C $fixture init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize disposable packaging test' }
    & git -C $fixture add .
    & git -C $fixture -c user.name=MacDictateTest -c user.email=synthetic@example.invalid commit -qm fixture
    if ($LASTEXITCODE -ne 0) { throw 'Cannot commit disposable fixture' }
    $output = Join-Path $fixture 'dist'
    $app = Join-Path $output 'MacDictate'
    New-Item -ItemType Directory -Path $app | Out-Null
    $sentinel = Join-Path $app 'original.md'
    Set-Content $sentinel 'preserve original app'
    $shell = (Get-Process -Id $PID).Path
    $message = & $shell -NoProfile -File (Join-Path $fixture 'scripts/build.ps1') 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -or $message -notmatch 'Output app folder already exists') { throw "Existing app guard did not stop before build: $message" }
    if ((Get-Content $sentinel -Raw).Trim() -ne 'preserve original app') { throw 'Existing app data was changed' }
    Remove-Item $app -Recurse # Only this test's synthetic fixture.
    $package = Join-Path $output $release.Portable
    Set-Content $package 'preserve release package'
    $message = & $shell -NoProfile -File (Join-Path $fixture 'scripts/build.ps1') 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -or $message -notmatch 'Versioned package already exists') { throw "Existing package guard did not stop: $message" }
    if ((Get-Content $package -Raw).Trim() -ne 'preserve release package') { throw 'Existing package bytes changed' }
    Write-Host 'Packaging guards PASS: prior app and versioned artifact preserved without native build.'
} finally { Remove-Item $fixture -Recurse -Force }
# Expected failing child builds must not leak exit 1 to GitHub's pwsh wrapper.
$global:LASTEXITCODE = 0
