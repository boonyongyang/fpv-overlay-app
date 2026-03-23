param(
    [string]$PythonBin = "",
    [string]$BuildDir = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($BuildDir)) {
    $BuildDir = Join-Path $RootDir "build\windows-runtime"
}

$VenvDir = Join-Path $RootDir ".venv-packaging-windows"

function Test-PythonModules {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonExe,
        [Parameter(Mandatory = $true)]
        [string[]]$Modules
    )

    $moduleList = ($Modules | ForEach-Object { "'$_'" }) -join ","
    $script = @"
import importlib.util
modules = [$moduleList]
missing = [m for m in modules if importlib.util.find_spec(m) is None]
raise SystemExit(0 if not missing else 1)
"@

    & $PythonExe -c $script *> $null
    return $LASTEXITCODE -eq 0
}

function Resolve-PythonPathFromLauncher {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Launcher,
        [string[]]$LauncherArgs = @()
    )

    if (-not (Get-Command $Launcher -ErrorAction SilentlyContinue)) {
        return $null
    }

    try {
        $resolvedPath = (& $Launcher @LauncherArgs -c "import sys; print(sys.executable)" 2>$null | Select-Object -First 1).Trim()
        if ([string]::IsNullOrWhiteSpace($resolvedPath)) {
            return $null
        }

        if (Test-PythonModules -PythonExe $resolvedPath -Modules @("numpy", "pandas", "PIL", "PyInstaller")) {
            return $resolvedPath
        }
    } catch {
        return $null
    }

    return $null
}

function Resolve-BootstrapPython {
    foreach ($candidate in @(
        @{ Launcher = "py"; Args = @("-3.11") },
        @{ Launcher = "py"; Args = @("-3") },
        @{ Launcher = "python"; Args = @() },
        @{ Launcher = "python3"; Args = @() }
    )) {
        if (-not (Get-Command $candidate.Launcher -ErrorAction SilentlyContinue)) {
            continue
        }

        try {
            & $candidate.Launcher @($candidate.Args + @("-c", "import sys")) *> $null
            if ($LASTEXITCODE -eq 0) {
                return $candidate
            }
        } catch {
            continue
        }
    }

    throw "Python 3.11+ was not found. Install Python on Windows and retry."
}

function Resolve-Python {
    if (-not [string]::IsNullOrWhiteSpace($PythonBin)) {
        if (Test-PythonModules -PythonExe $PythonBin -Modules @("numpy", "pandas", "PIL", "PyInstaller")) {
            return $PythonBin
        }
    }

    foreach ($candidate in @(
        @{ Launcher = "py"; Args = @("-3.11") },
        @{ Launcher = "py"; Args = @("-3.12") },
        @{ Launcher = "py"; Args = @("-3") },
        @{ Launcher = "python"; Args = @() },
        @{ Launcher = "python3"; Args = @() }
    )) {
        $resolved = Resolve-PythonPathFromLauncher -Launcher $candidate.Launcher -LauncherArgs $candidate.Args
        if (-not [string]::IsNullOrWhiteSpace($resolved)) {
            return $resolved
        }
    }

    $bootstrap = Resolve-BootstrapPython
    if (-not (Test-Path $VenvDir)) {
        & $bootstrap.Launcher @($bootstrap.Args + @("-m", "venv", $VenvDir))
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to create .venv-packaging-windows. Install Python 3.11 and retry."
        }
    }

    $venvPython = Join-Path $VenvDir "Scripts\python.exe"
    & $venvPython -m pip install --quiet pyinstaller numpy pandas pillow
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install PyInstaller runtime build dependencies into .venv-packaging-windows."
    }

    return $venvPython
}

function Build-OverlayExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [string[]]$ExtraArgs = @()
    )

    $args = @(
        "-m", "PyInstaller",
        "--noconfirm",
        "--clean",
        "--name", $Name,
        "--onedir",
        "--distpath", (Join-Path $BuildDir "dist"),
        "--workpath", (Join-Path $BuildDir "work"),
        "--specpath", (Join-Path $BuildDir "spec")
    ) + $ExtraArgs + @($ScriptPath)

    Write-Host "Building $Name from $ScriptPath"
    & $PythonExe @args
    if ($LASTEXITCODE -ne 0) {
        throw "PyInstaller failed while building $Name."
    }
}

$PythonExe = Resolve-Python

if (Test-Path $BuildDir) {
    Remove-Item $BuildDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path `
    (Join-Path $BuildDir "dist"), `
    (Join-Path $BuildDir "work"), `
    (Join-Path $BuildDir "spec") | Out-Null

$assetBinDir = Join-Path $RootDir "assets\bin"

Build-OverlayExecutable `
    -Name "osd_overlay" `
    -ScriptPath (Join-Path $assetBinDir "osd_overlay.py") `
    -ExtraArgs @(
        "--paths", $assetBinDir,
        "--add-data", "$assetBinDir\fonts;fonts"
    )

Build-OverlayExecutable `
    -Name "srt_overlay" `
    -ScriptPath (Join-Path $assetBinDir "srt_overlay.py")

Write-Host "Built standalone Windows overlay executables in $(Join-Path $BuildDir 'dist')"
