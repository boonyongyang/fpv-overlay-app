#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_PATH="$ROOT_DIR/packaging/homebrew/Formula/fpv-overlay.rb"
OUTPUT_PATH=""
RELEASE_TAG=""
VERSION=""
ARM64_SHA=""
X64_SHA=""

usage() {
    cat <<'EOF'
Usage:
  tools/render_homebrew_formula.sh \
    --tag v0.1.0 \
    --version 0.1.0 \
    --arm64-sha <sha256> \
    --x64-sha <sha256> \
    --output /path/to/fpv-overlay.rb
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag)
            RELEASE_TAG="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --arm64-sha)
            ARM64_SHA="$2"
            shift 2
            ;;
        --x64-sha)
            X64_SHA="$2"
            shift 2
            ;;
        --output)
            OUTPUT_PATH="$2"
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

if [[ -z "$RELEASE_TAG" || -z "$VERSION" || -z "$ARM64_SHA" || -z "$X64_SHA" || -z "$OUTPUT_PATH" ]]; then
    echo "Missing required arguments." >&2
    usage >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

sed \
    -e "s|__RELEASE_TAG__|$RELEASE_TAG|g" \
    -e "s|__VERSION__|$VERSION|g" \
    -e "s|__ARM64_SHA256__|$ARM64_SHA|g" \
    -e "s|__X64_SHA256__|$X64_SHA|g" \
    "$TEMPLATE_PATH" >"$OUTPUT_PATH"

echo "Rendered Homebrew formula to $OUTPUT_PATH"
