param(
    [string]$AppDir = "",
    [string]$Version = "",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($AppDir)) {
    $AppDir = Join-Path $RootDir "build\windows\x64\runner\Release"
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $pubspecVersionLine = Select-String -Path (Join-Path $RootDir "pubspec.yaml") -Pattern "^version:\s*(.+)$" | Select-Object -First 1
    if ($null -eq $pubspecVersionLine) {
        throw "Unable to determine app version from pubspec.yaml."
    }
    $Version = ($pubspecVersionLine.Matches[0].Groups[1].Value -split "\+")[0]
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RootDir "dist\windows"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

& (Join-Path $PSScriptRoot "prepare_windows_release.ps1") -AppDir $AppDir
if ($LASTEXITCODE -ne 0) {
    throw "Failed while preparing the Windows release runtime."
}

$isccCandidates = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($env:ISCC_PATH)) {
    $isccCandidates.Add($env:ISCC_PATH)
}
if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
    $isccCandidates.Add((Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"))
}
if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
    $isccCandidates.Add((Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe"))
}

$isccPath = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($null -eq $isccPath) {
    throw "Inno Setup 6 was not found. Install it or set ISCC_PATH to ISCC.exe."
}

$issPath = Join-Path $RootDir "windows\installer\fpv_overlay_toolbox.iss"
& $isccPath `
    "/DMyAppVersion=$Version" `
    "/DMyAppDir=$AppDir" `
    "/DMyOutputDir=$OutputDir" `
    $issPath

if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed while creating the Windows installer."
}

Write-Host "Created Windows installer in $OutputDir"
