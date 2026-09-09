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

rendered_plist="$(mktemp "${TMPDIR:-/tmp}/com.zachking.CaffeinateSwitch.XXXXXX.plist")"
trap 'rm -f "$rendered_plist"' EXIT
render_template > "$rendered_plist"
plutil -lint "$rendered_plist"

mkdir -p "$APPLICATIONS_DIR" "$LAUNCH_AGENTS_DIR"
if [ -e "$INSTALLED_PLIST" ]; then
    launchctl bootout "gui/$(id -u)" "$INSTALLED_PLIST" 2>/dev/null || true
fi
# Replace only this project's installed bundle so stale bundle contents cannot survive an upgrade.
rm -rf "$INSTALLED_APP"
ditto "$SOURCE_APP" "$INSTALLED_APP"
install -m 644 "$rendered_plist" "$INSTALLED_PLIST"
launchctl bootstrap "gui/$(id -u)" "$INSTALLED_PLIST"

echo "Installed: $INSTALLED_APP"
echo "Loaded: $INSTALLED_PLIST"
