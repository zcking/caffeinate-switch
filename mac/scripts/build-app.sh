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
APP_BUNDLE="$BUILD_ROOT/Caffeinate Switch.app"
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

mkdir -p "$BUILD_ROOT"
STAGED_APP="$(mktemp -d "$BUILD_ROOT/.Caffeinate Switch.app.staging.XXXXXX")"
BACKUP_APP="${STAGED_APP}.previous"
new_bundle_installed=false

cleanup_staged_bundle() {
    local status=$?
    trap - EXIT

    if [ -e "$BACKUP_APP" ]; then
        if "$new_bundle_installed"; then
            rm -rf "$BACKUP_APP"
        elif [ ! -e "$APP_BUNDLE" ]; then
            mv "$BACKUP_APP" "$APP_BUNDLE" || \
                echo "Error: could not restore previous bundle: $BACKUP_APP" >&2
        else
            echo "Error: preserving previous bundle at $BACKUP_APP after incomplete swap" >&2
        fi
    fi
    [ ! -e "$STAGED_APP" ] || rm -rf "$STAGED_APP"
    exit "$status"
}
trap cleanup_staged_bundle EXIT

STAGED_CONTENTS="$STAGED_APP/Contents"
mkdir -p "$STAGED_CONTENTS/MacOS" "$STAGED_CONTENTS/Resources"
cp "$RELEASE_EXECUTABLE" "$STAGED_CONTENTS/MacOS/CaffeinateSwitchApp"
cp "$INFO_PLIST" "$STAGED_CONTENTS/Info.plist"
plutil -lint "$STAGED_CONTENTS/Info.plist"

# Both directories are siblings on one filesystem. Preserve the old bundle until the staged bundle is valid.
if [ -e "$APP_BUNDLE" ]; then
    mv "$APP_BUNDLE" "$BACKUP_APP"
fi
mv "$STAGED_APP" "$APP_BUNDLE"
new_bundle_installed=true
[ ! -e "$BACKUP_APP" ] || rm -rf "$BACKUP_APP"
trap - EXIT

echo "Built: $APP_BUNDLE"
