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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
MAC_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
REPO_ROOT="$(cd -- "$MAC_DIR/.." && pwd -P)"
TEMPLATE="$MAC_DIR/Resources/com.zachking.CaffeinateSwitch.plist.template"
source "$SCRIPT_DIR/launch-agent.sh"

absolute_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$(pwd -P)" "$1" ;;
    esac
}

BUILD_ROOT="$(absolute_path "${BUILD_ROOT:-$REPO_ROOT/build}")"
SOURCE_APP="$BUILD_ROOT/Caffeinate Switch.app"
APPLICATIONS_DIR="$HOME/Applications"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
INSTALLED_APP="$APPLICATIONS_DIR/Caffeinate Switch.app"
INSTALLED_EXECUTABLE="$INSTALLED_APP/Contents/MacOS/CaffeinateSwitchApp"
INSTALLED_PLIST="$LAUNCH_AGENTS_DIR/com.zachking.CaffeinateSwitch.plist"
LAUNCH_AGENT_TARGET="gui/$(id -u)/com.zachking.CaffeinateSwitch"

[ -f "$TEMPLATE" ] || die "LaunchAgent template is missing: $TEMPLATE"

xml_escape() {
    printf '%s' "$1" | sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g' \
        -e "s/'/\&apos;/g"
}

render_template() {
    local escaped_executable line prefix suffix
    escaped_executable="$(xml_escape "$INSTALLED_EXECUTABLE")"
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            *'__APP_EXECUTABLE__'*)
                prefix="${line%%__APP_EXECUTABLE__*}"
                suffix="${line#*__APP_EXECUTABLE__}"
                printf '%s%s%s\n' "$prefix" "$escaped_executable" "$suffix"
                ;;
            *) printf '%s\n' "$line" ;;
        esac
    done < "$TEMPLATE"
}

if "$dry_run"; then
    bash "$SCRIPT_DIR/build-app.sh" --dry-run
    render_template | plutil -lint - >/dev/null
    render_template
    exit 0
fi

bash "$SCRIPT_DIR/build-app.sh"
[ -d "$SOURCE_APP" ] || die "application bundle was not produced: $SOURCE_APP"

mkdir -p "$APPLICATIONS_DIR" "$LAUNCH_AGENTS_DIR"
STAGED_APP="$(mktemp -d "$APPLICATIONS_DIR/.Caffeinate Switch.app.staging.XXXXXX")"
STAGED_PLIST="$(mktemp "$LAUNCH_AGENTS_DIR/.com.zachking.CaffeinateSwitch.plist.staging.XXXXXX")"
BACKUP_APP="${STAGED_APP}.previous"
new_bundle_installed=false

cleanup_staged_install() {
    local status=$?
    trap - EXIT
    rm -f "$STAGED_PLIST"

    if [ -e "$BACKUP_APP" ]; then
        if "$new_bundle_installed"; then
            rm -rf "$BACKUP_APP"
        elif [ ! -e "$INSTALLED_APP" ]; then
            mv "$BACKUP_APP" "$INSTALLED_APP" || \
                echo "Error: could not restore previous bundle: $BACKUP_APP" >&2
        else
            echo "Error: preserving previous bundle at $BACKUP_APP after incomplete swap" >&2
        fi
    fi
    [ ! -e "$STAGED_APP" ] || rm -rf "$STAGED_APP"
    exit "$status"
}
trap cleanup_staged_install EXIT

# Stage and validate both replacements before unloading or replacing the existing login application.
ditto "$SOURCE_APP" "$STAGED_APP"
plutil -lint "$STAGED_APP/Contents/Info.plist"
render_template > "$STAGED_PLIST"
plutil -lint "$STAGED_PLIST"
chmod 644 "$STAGED_PLIST"

bootout_launch_agent "$LAUNCH_AGENT_TARGET" || \
    die "could not safely unload $LAUNCH_AGENT_TARGET"
if [ -e "$INSTALLED_APP" ]; then
    mv "$INSTALLED_APP" "$BACKUP_APP"
fi
mv "$STAGED_APP" "$INSTALLED_APP"
new_bundle_installed=true
[ ! -e "$BACKUP_APP" ] || rm -rf "$BACKUP_APP"
mv "$STAGED_PLIST" "$INSTALLED_PLIST"
launchctl bootstrap "gui/$(id -u)" "$INSTALLED_PLIST"
trap - EXIT

echo "Installed: $INSTALLED_APP"
echo "Loaded: $INSTALLED_PLIST"
