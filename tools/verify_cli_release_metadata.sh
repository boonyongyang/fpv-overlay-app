#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_PUBSPEC="$ROOT_DIR/cli/pubspec.yaml"
CLI_APP="$ROOT_DIR/cli/lib/src/app.dart"
FORMULA_TEMPLATE="$ROOT_DIR/packaging/homebrew/Formula/fpv-overlay.rb"
TAG=""

usage() {
    cat <<'EOF'
Usage:
  tools/verify_cli_release_metadata.sh [--tag v0.1.0]
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag)
            TAG="$2"
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

CLI_VERSION="$(grep '^version:' "$CLI_PUBSPEC" | awk '{print $2}')"
DEFAULT_VERSION="$(grep -o "defaultValue: '[^']*'" "$CLI_APP" | head -n 1 | sed "s/defaultValue: '//; s/'//")"

if [[ -z "$CLI_VERSION" ]]; then
    echo "Unable to read CLI version from $CLI_PUBSPEC" >&2
    exit 1
fi

if [[ -z "$DEFAULT_VERSION" ]]; then
    echo "Unable to read CLI default version from $CLI_APP" >&2
    exit 1
fi

if [[ "$CLI_VERSION" != "$DEFAULT_VERSION" ]]; then
    echo "CLI version mismatch:" >&2
    echo "  cli/pubspec.yaml: $CLI_VERSION" >&2
    echo "  cli/lib/src/app.dart default: $DEFAULT_VERSION" >&2
    exit 1
fi

if [[ -n "$TAG" ]]; then
    TAG_VERSION="${TAG#v}"
    TAG_VERSION="${TAG_VERSION%%-*}"
    if [[ "$TAG_VERSION" != "$CLI_VERSION" ]]; then
        echo "Release tag does not match CLI version:" >&2
        echo "  tag: $TAG" >&2
        echo "  cli/pubspec.yaml: $CLI_VERSION" >&2
        exit 1
    fi
fi

for placeholder in __RELEASE_TAG__ __VERSION__ __ARM64_SHA256__ __X64_SHA256__; do
    if ! grep -q "$placeholder" "$FORMULA_TEMPLATE"; then
        echo "Missing placeholder $placeholder in $FORMULA_TEMPLATE" >&2
        exit 1
    fi
done

echo "CLI release metadata is consistent."
echo "Version: $CLI_VERSION"
if [[ -n "$TAG" ]]; then
    echo "Tag: $TAG"
fi
