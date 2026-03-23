#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/macos-runtime"
VENV_DIR="$ROOT_DIR/.venv-packaging"
PYINSTALLER="$VENV_DIR/bin/pyinstaller"

resolve_python() {
    if [[ -n "${PYTHON_BIN:-}" && -x "${PYTHON_BIN}" ]]; then
        printf '%s\n' "${PYTHON_BIN}"
        return 0
    fi

    local candidates=(
        /opt/homebrew/bin/python3.11
        /opt/homebrew/bin/python3.12
        /opt/homebrew/bin/python3
        /usr/local/bin/python3.11
        /usr/local/bin/python3
        "$(command -v python3 2>/dev/null || true)"
    )

    local candidate
    for candidate in "${candidates[@]}"; do
        [[ -n "$candidate" && -x "$candidate" ]] || continue
        if "$candidate" - <<'PY' >/dev/null 2>&1
import importlib.util
mods = ["numpy", "pandas", "PIL", "PyInstaller"]
missing = [m for m in mods if importlib.util.find_spec(m) is None]
raise SystemExit(1 if missing else 0)
PY
        then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    local bootstrap="${candidates[0]}"
    if [[ ! -x "$bootstrap" ]]; then
        bootstrap="$(command -v python3)"
    fi

    if [[ ! -d "$VENV_DIR" ]]; then
        "$bootstrap" -m venv "$VENV_DIR"
    fi

    "$VENV_DIR/bin/pip" install --quiet pyinstaller numpy pandas pillow
    printf '%s\n' "$VENV_DIR/bin/python"
}

PYTHON_BIN="$(resolve_python)"

if [[ "$PYTHON_BIN" == "$VENV_DIR/bin/python" ]]; then
    PYINSTALLER="$VENV_DIR/bin/pyinstaller"
else
    PYINSTALLER="$PYTHON_BIN -m PyInstaller"
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/spec" "$BUILD_DIR/work" "$BUILD_DIR/dist"

build_overlay() {
    local name="$1"
    local script_path="$2"
    local extra_args=("${@:3}")

    echo "Building $name from $script_path"

    if [[ "$PYINSTALLER" == *" -m PyInstaller" ]]; then
        # shellcheck disable=SC2086
        $PYINSTALLER \
            --noconfirm \
            --clean \
            --name "$name" \
            --onedir \
            --distpath "$BUILD_DIR/dist" \
            --workpath "$BUILD_DIR/work" \
            --specpath "$BUILD_DIR/spec" \
            "${extra_args[@]:+${extra_args[@]}}" \
            "$script_path"
    else
        "$VENV_DIR/bin/pyinstaller" \
            --noconfirm \
            --clean \
            --name "$name" \
            --onedir \
            --distpath "$BUILD_DIR/dist" \
            --workpath "$BUILD_DIR/work" \
            --specpath "$BUILD_DIR/spec" \
            "${extra_args[@]:+${extra_args[@]}}" \
            "$script_path"
    fi
}

build_overlay \
    osd_overlay \
    "$ROOT_DIR/assets/bin/osd_overlay.py" \
    --paths "$ROOT_DIR/assets/bin" \
    --add-data "$ROOT_DIR/assets/bin/fonts:fonts"

build_overlay \
    srt_overlay \
    "$ROOT_DIR/assets/bin/srt_overlay.py"

echo "Built standalone overlay executables in $BUILD_DIR/dist"
