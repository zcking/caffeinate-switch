#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") [--dry-run]" >&2
}

die() {
    echo "Error: $*" >&2
    exit 1
}

dry_run=false
case "${1:-}" in
    '') ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
MAC_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
REPO_ROOT="$(cd -- "$MAC_DIR/.." && pwd -P)"
PACKAGE_DIR="$MAC_DIR/CaffeinateSwitch"

absolute_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$(pwd -P)" "$1" ;;
    esac
}

BUILD_ROOT="$(absolute_path "${BUILD_ROOT:-$REPO_ROOT/build}")"
APP_CONTENTS="$BUILD_ROOT/Caffeinate Switch.app/Contents"
APP_EXECUTABLE="$APP_CONTENTS/MacOS/CaffeinateSwitchApp"
INFO_PLIST="$MAC_DIR/Resources/Info.plist"

[ -d "$PACKAGE_DIR" ] || die "Swift package directory is missing: $PACKAGE_DIR"
[ -f "$INFO_PLIST" ] || die "application Info.plist is missing: $INFO_PLIST"

if "$dry_run"; then
    echo "DRY RUN: (cd \"$PACKAGE_DIR\" && swift build -c release)" >&2
    echo "DRY RUN: assemble \"$BUILD_ROOT/Caffeinate Switch.app\"" >&2
    exit 0
fi

(
    cd -- "$PACKAGE_DIR"
    swift build -c release
)

BIN_PATH="$(
    cd -- "$PACKAGE_DIR"
    swift build -c release --show-bin-path
)"
RELEASE_EXECUTABLE="$BIN_PATH/CaffeinateSwitchApp"
[ -f "$RELEASE_EXECUTABLE" ] || die "release executable was not produced: $RELEASE_EXECUTABLE"

mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources"
cp "$RELEASE_EXECUTABLE" "$APP_EXECUTABLE"
cp "$INFO_PLIST" "$APP_CONTENTS/Info.plist"
plutil -lint "$APP_CONTENTS/Info.plist"

echo "Built: $BUILD_ROOT/Caffeinate Switch.app"
