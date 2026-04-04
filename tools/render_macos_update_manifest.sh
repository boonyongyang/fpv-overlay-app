#!/bin/bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  tools/render_macos_update_manifest.sh \
    --output /path/to/latest-macos.json \
    --repository owner/repo \
    --release-tag v1.0.0 \
    --version 1.0.0 \
    --artifact-name fpv-overlay-toolbox-macos-1.0.0.dmg \
    --sha256 <sha256> \
    --published-at 2026-03-26T12:34:56Z
EOF
}

OUTPUT_PATH=""
REPOSITORY=""
RELEASE_TAG=""
VERSION=""
ARTIFACT_NAME=""
SHA256=""
PUBLISHED_AT=""
CHANNEL="stable"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        --repository)
            REPOSITORY="$2"
            shift 2
            ;;
        --release-tag)
            RELEASE_TAG="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --artifact-name)
            ARTIFACT_NAME="$2"
            shift 2
            ;;
        --sha256)
            SHA256="$2"
            shift 2
            ;;
        --published-at)
            PUBLISHED_AT="$2"
            shift 2
            ;;
        --channel)
            CHANNEL="$2"
            shift 2
            ;;
        -h|--help)
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

for required in OUTPUT_PATH REPOSITORY RELEASE_TAG VERSION ARTIFACT_NAME SHA256 PUBLISHED_AT; do
    if [[ -z "${!required}" ]]; then
        echo "Missing required argument: ${required}" >&2
        usage >&2
        exit 1
    fi
done

mkdir -p "$(dirname "$OUTPUT_PATH")"

ARTIFACT_URL="https://github.com/${REPOSITORY}/releases/download/${RELEASE_TAG}/${ARTIFACT_NAME}"
RELEASE_URL="https://github.com/${REPOSITORY}/releases/tag/${RELEASE_TAG}"
MANIFEST_URL="https://github.com/${REPOSITORY}/releases/latest/download/latest-macos.json"

cat >"$OUTPUT_PATH" <<EOF
{
  "platform": "macos",
  "channel": "${CHANNEL}",
  "version": "${VERSION}",
  "release_tag": "${RELEASE_TAG}",
  "published_at": "${PUBLISHED_AT}",
  "artifact_name": "${ARTIFACT_NAME}",
  "artifact_url": "${ARTIFACT_URL}",
  "sha256": "${SHA256}",
  "release_url": "${RELEASE_URL}",
  "manifest_url": "${MANIFEST_URL}"
}
EOF

echo "Rendered macOS update manifest: $OUTPUT_PATH"
