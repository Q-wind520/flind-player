# Stages the MSVC runtime DLLs next to flind_player.exe (app-local deployment),
# so both the portable zip and the Inno Setup installer run on machines that do
# not have the Visual C++ Redistributable installed.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseDir
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    throw "release dir not found: $ReleaseDir"
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) {
    throw "vswhere.exe not found at $vswhere (Visual Studio Build Tools required)"
}

$vsPath = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath
if (-not $vsPath) { throw 'Visual Studio with the C++ toolset was not found' }

$crtDir = Get-ChildItem -Path (Join-Path $vsPath 'VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT') -Directory |
    Sort-Object -Property FullName |
    Select-Object -Last 1
if (-not $crtDir) { throw 'MSVC CRT redist directory not found' }

$dlls = @(Get-ChildItem -Path (Join-Path $crtDir.FullName '*.dll'))
if ($dlls.Count -eq 0) { throw "no DLLs found in $($crtDir.FullName)" }

foreach ($dll in $dlls) {
    Copy-Item -LiteralPath $dll.FullName -Destination (Join-Path $ReleaseDir $dll.Name) -Force
}

$staged = ($dlls | ForEach-Object { $_.Name }) -join ', '
Write-Host "staged $($dlls.Count) CRT DLLs into ${ReleaseDir}: $staged"
if (-not ($dlls.Name -contains 'vcruntime140.dll')) {
    throw 'vcruntime140.dll was not among the staged DLLs'
}
