param(
    [string]$AppDir = "",
    [string]$FfmpegUrl = "https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-8.0.1-essentials_build.zip"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($AppDir)) {
    $AppDir = Join-Path $RootDir "build\windows\x64\runner\Release"
}

$appExePath = Join-Path $AppDir "fpv-overlay-toolbox.exe"
if (-not (Test-Path $appExePath)) {
    throw "Windows app bundle not found at $AppDir. Run 'flutter build windows --release' on Windows first."
}

& (Join-Path $PSScriptRoot "build_windows_overlay_runtime.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Failed to build the standalone Windows overlay executables."
}

$runtimeDir = Join-Path $AppDir "runtime"
if (Test-Path $runtimeDir) {
    Remove-Item $runtimeDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

$downloadDir = Join-Path $RootDir "build\windows-downloads"
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

$ffmpegZipName = [IO.Path]::GetFileName(($FfmpegUrl -split "\?")[0])
$ffmpegZipPath = Join-Path $downloadDir $ffmpegZipName
if (-not (Test-Path $ffmpegZipPath)) {
    Write-Host "Downloading $ffmpegZipName"
    Invoke-WebRequest -Uri $FfmpegUrl -OutFile $ffmpegZipPath
}

$extractDir = Join-Path $env:TEMP ("fpv-overlay-ffmpeg-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
try {
    Expand-Archive -LiteralPath $ffmpegZipPath -DestinationPath $extractDir -Force

    $ffmpegExe = Get-ChildItem -Path $extractDir -Filter "ffmpeg.exe" -Recurse | Select-Object -First 1
    if ($null -eq $ffmpegExe) {
        throw "Could not locate ffmpeg.exe inside $ffmpegZipName."
    }

    $ffmpegBinDir = $ffmpegExe.Directory.FullName
    Copy-Item -Path (Join-Path $ffmpegBinDir "*") -Destination $runtimeDir -Recurse -Force
} finally {
    if (Test-Path $extractDir) {
        Remove-Item $extractDir -Recurse -Force
    }
}

$overlayDistDir = Join-Path $RootDir "build\windows-runtime\dist"
Copy-Item -Path (Join-Path $overlayDistDir "osd_overlay") -Destination $runtimeDir -Recurse -Force
Copy-Item -Path (Join-Path $overlayDistDir "srt_overlay") -Destination $runtimeDir -Recurse -Force

Write-Host "Prepared bundled Windows runtime in $runtimeDir"
