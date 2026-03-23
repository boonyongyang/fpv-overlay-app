#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/build/macos/Build/Products/Release/FPV Overlay Toolbox.app}"
VERSION="${2:-$(grep '^version:' "$ROOT_DIR/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)}"
DMG_NAME="fpv-overlay-toolbox-macos-${VERSION}.dmg"
OUTPUT_DIR="${ROOT_DIR}/dist"
PREPARE_RUNTIME_SCRIPT="${ROOT_DIR}/tools/prepare_macos_app_runtime.sh"
TEMP_DIR="$(mktemp -d)"
STAGING_DIR="${TEMP_DIR}/FPV Overlay Toolbox"

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App bundle not found: $APP_PATH"
    echo "   Build it first with: flutter build macos --release"
    exit 1
fi

"$PREPARE_RUNTIME_SCRIPT" "$APP_PATH"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "FPV Overlay Toolbox" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$OUTPUT_DIR/$DMG_NAME" >/dev/null

echo "✅ Created: $OUTPUT_DIR/$DMG_NAME"
