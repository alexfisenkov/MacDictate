# The Windows csproj Version is the only candidate-version literal used by packaging.
function Get-WindowsReleaseInfo {
    $windowsRoot = Split-Path $PSScriptRoot -Parent
    [xml]$project = Get-Content (Join-Path $windowsRoot 'src/MacDictate.Windows/MacDictate.Windows.csproj') -Raw
    $version = [string]$project.Project.PropertyGroup.Version
    if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Windows csproj must define one semantic Version' }
    $baseName = "MacDictate_Windows_v$version`_x64"
    [pscustomobject]@{ Version = $version; Tag = "v$version"; BaseName = $baseName; Installer = "$baseName.exe"; Portable = "$baseName.zip" }
}
