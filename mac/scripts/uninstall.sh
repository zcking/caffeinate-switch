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

[ -n "${HOME:-}" ] || die "HOME must be set"
case "$HOME" in
    /*) ;;
    *) die "HOME must be an absolute path" ;;
esac

INSTALLED_APP="$HOME/Applications/Caffeinate Switch.app"
INSTALLED_PLIST="$HOME/Library/LaunchAgents/com.zachking.CaffeinateSwitch.plist"

if "$dry_run"; then
    echo "DRY RUN: launchctl bootout gui/$(id -u) \"$INSTALLED_PLIST\" (if present)" >&2
    echo "DRY RUN: remove \"$INSTALLED_APP\"" >&2
    echo "DRY RUN: remove \"$INSTALLED_PLIST\"" >&2
    exit 0
fi

if [ -e "$INSTALLED_PLIST" ]; then
    launchctl bootout "gui/$(id -u)" "$INSTALLED_PLIST" 2>/dev/null || true
    rm -f "$INSTALLED_PLIST"
fi

if [ -e "$INSTALLED_APP" ]; then
    rm -rf "$INSTALLED_APP"
fi

echo "Uninstalled Caffeinate Switch"
