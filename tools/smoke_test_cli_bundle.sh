#!/bin/bash

set -euo pipefail

BUNDLE_DIR=""
ARCHIVE_PATH=""
EXPECTED_VERSION=""
TEMP_DIR=""
WORK_DIR=""

usage() {
    cat <<'EOF'
Usage:
  tools/smoke_test_cli_bundle.sh --bundle-dir /path/to/fpv-overlay-cli-macos-arm64-1.0.0 [--version 0.1.0]
  tools/smoke_test_cli_bundle.sh --archive /path/to/fpv-overlay-cli-macos-arm64-1.0.0.tar.gz [--version 0.1.0]
EOF
}

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bundle-dir)
            BUNDLE_DIR="$2"
            shift 2
            ;;
        --archive)
            ARCHIVE_PATH="$2"
            shift 2
            ;;
        --version)
            EXPECTED_VERSION="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -n "$BUNDLE_DIR" && -n "$ARCHIVE_PATH" ]]; then
    echo "Specify either --bundle-dir or --archive, not both." >&2
    exit 1
fi

if [[ -z "$BUNDLE_DIR" && -z "$ARCHIVE_PATH" ]]; then
    echo "Missing required bundle input." >&2
    usage >&2
    exit 1
fi

if [[ -n "$ARCHIVE_PATH" ]]; then
    if [[ ! -f "$ARCHIVE_PATH" ]]; then
        echo "Archive not found: $ARCHIVE_PATH" >&2
        exit 1
    fi
    TEMP_DIR="$(mktemp -d)"
    tar -C "$TEMP_DIR" -xzf "$ARCHIVE_PATH"
    BUNDLE_DIR="$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
fi

if [[ ! -d "$BUNDLE_DIR" ]]; then
    echo "Bundle directory not found: $BUNDLE_DIR" >&2
    exit 1
fi

BUNDLE_DIR="$(cd "$BUNDLE_DIR" && pwd)"
CLI_BIN="$BUNDLE_DIR/bin/fpv-overlay"
RUNTIME_DIR="$BUNDLE_DIR/runtime"

for required_path in \
    "$CLI_BIN" \
    "$RUNTIME_DIR/ffmpeg" \
    "$RUNTIME_DIR/ffprobe" \
    "$RUNTIME_DIR/osd_overlay/osd_overlay" \
    "$RUNTIME_DIR/srt_overlay/srt_overlay"; do
    if [[ ! -e "$required_path" ]]; then
        echo "Missing required bundle path: $required_path" >&2
        exit 1
    fi
done

if [[ ! -x "$CLI_BIN" ]]; then
    echo "CLI binary is not executable: $CLI_BIN" >&2
    exit 1
fi

VERSION_OUTPUT="$("$CLI_BIN" --version)"
echo "$VERSION_OUTPUT"

if [[ -n "$EXPECTED_VERSION" ]]; then
    if [[ "$VERSION_OUTPUT" != "fpv-overlay $EXPECTED_VERSION" ]]; then
        echo "Unexpected CLI version output: $VERSION_OUTPUT" >&2
        exit 1
    fi
fi

DOCTOR_OUTPUT="$("$CLI_BIN" doctor)"
echo "$DOCTOR_OUTPUT"

for expected_snippet in \
    "FFmpeg: $RUNTIME_DIR/ffmpeg" \
    "FFprobe: $RUNTIME_DIR/ffprobe" \
    "OSD runtime: $RUNTIME_DIR/osd_overlay/osd_overlay" \
    "SRT runtime: $RUNTIME_DIR/srt_overlay/srt_overlay"; do
    if ! grep -Fq "$expected_snippet" <<<"$DOCTOR_OUTPUT"; then
        echo "Doctor output missing expected runtime path: $expected_snippet" >&2
        exit 1
    fi
done

WORK_DIR="$(mktemp -d)"
touch "$WORK_DIR/clip.mp4"
cat <<'EOF' >"$WORK_DIR/clip.srt"
1
00:00:00,000 --> 00:00:01,000
test
EOF

RENDER_OUTPUT="$("$CLI_BIN" render --video "$WORK_DIR/clip.mp4" --srt "$WORK_DIR/clip.srt" --dry-run)"
echo "$RENDER_OUTPUT"

if ! grep -Fq "Dry run complete." <<<"$RENDER_OUTPUT"; then
    echo "Render dry run did not complete successfully." >&2
    exit 1
fi

echo "CLI bundle smoke test passed."
