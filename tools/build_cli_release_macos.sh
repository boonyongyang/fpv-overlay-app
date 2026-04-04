#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_DIR="$ROOT_DIR/cli"
BUILD_DIR="$ROOT_DIR/build/cli-release"
RUNTIME_BUILD_SCRIPT="$ROOT_DIR/tools/build_cli_runtime_macos.sh"
SMOKE_TEST_SCRIPT="$ROOT_DIR/tools/smoke_test_cli_bundle.sh"
RUNTIME_DIR="$ROOT_DIR/build/cli-runtime/runtime"
VERSION="$(grep '^version:' "$CLI_DIR/pubspec.yaml" | awk '{print $2}')"
ARCH_RAW="$(uname -m)"

case "$ARCH_RAW" in
    arm64) ARCH="arm64" ;;
    x86_64) ARCH="x64" ;;
    *)
        echo "Unsupported macOS architecture: $ARCH_RAW"
        exit 1
        ;;
esac

BUNDLE_NAME="fpv-overlay-cli-macos-${ARCH}-${VERSION}"
STAGE_DIR="$BUILD_DIR/$BUNDLE_NAME"
ARCHIVE_PATH="$BUILD_DIR/$BUNDLE_NAME.tar.gz"
CHECKSUM_PATH="$BUILD_DIR/$BUNDLE_NAME.sha256"

"$RUNTIME_BUILD_SCRIPT"

rm -rf "$BUILD_DIR"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/bin"
mkdir -p "$BUILD_DIR"

(
    cd "$CLI_DIR"
    dart pub get
    dart compile exe \
        -Dfpv_overlay_cli_version="$VERSION" \
        bin/fpv_overlay.dart \
        -o "$STAGE_DIR/bin/fpv-overlay"
)

chmod +x "$STAGE_DIR/bin/fpv-overlay"
cp -R "$RUNTIME_DIR" "$STAGE_DIR/runtime"

bash "$SMOKE_TEST_SCRIPT" --bundle-dir "$STAGE_DIR" --version "$VERSION"

tar -C "$BUILD_DIR" -czf "$ARCHIVE_PATH" "$BUNDLE_NAME"
shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}' >"$CHECKSUM_PATH"

echo "Built CLI release archive: $ARCHIVE_PATH"
echo "SHA256 written to: $CHECKSUM_PATH"
