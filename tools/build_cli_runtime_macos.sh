#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$ROOT_DIR/build/cli-runtime/runtime"
FFMPEG_VERSION="${FFMPEG_VERSION:-8.0.1}"
FFMPEG_BASE_URL="${FFMPEG_BASE_URL:-https://deolaha.ca/ffmpeg}"
BUILD_RUNTIME_SCRIPT="$ROOT_DIR/tools/build_macos_overlay_runtime.sh"
OVERLAY_DIST_DIR="$ROOT_DIR/build/macos-runtime/dist"
DOWNLOAD_DIR="$ROOT_DIR/build/downloads"

"$BUILD_RUNTIME_SCRIPT"

rm -rf "$RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR"
mkdir -p "$DOWNLOAD_DIR"

download_zip() {
    local url="$1"
    local output_path="$2"
    if [[ ! -f "$output_path" ]]; then
        echo "Downloading $(basename "$output_path")"
        curl -L --fail --retry 3 --output "$output_path" "$url"
    fi
}

extract_binary() {
    local zip_path="$1"
    local binary_name="$2"
    local output_path="$3"
    unzip -p "$zip_path" "$binary_name" >"$output_path"
    chmod +x "$output_path"
}

download_zip \
    "$FFMPEG_BASE_URL/ffmpeg-${FFMPEG_VERSION}.zip" \
    "$DOWNLOAD_DIR/ffmpeg-${FFMPEG_VERSION}.zip"
download_zip \
    "$FFMPEG_BASE_URL/ffprobe-${FFMPEG_VERSION}.zip" \
    "$DOWNLOAD_DIR/ffprobe-${FFMPEG_VERSION}.zip"

extract_binary \
    "$DOWNLOAD_DIR/ffmpeg-${FFMPEG_VERSION}.zip" \
    ffmpeg \
    "$RUNTIME_DIR/ffmpeg"
extract_binary \
    "$DOWNLOAD_DIR/ffprobe-${FFMPEG_VERSION}.zip" \
    ffprobe \
    "$RUNTIME_DIR/ffprobe"

cp -R "$OVERLAY_DIST_DIR/osd_overlay" "$RUNTIME_DIR/"
cp -R "$OVERLAY_DIST_DIR/srt_overlay" "$RUNTIME_DIR/"

chmod +x "$RUNTIME_DIR/osd_overlay/osd_overlay" "$RUNTIME_DIR/srt_overlay/srt_overlay"

echo "Prepared standalone CLI runtime in $RUNTIME_DIR"

