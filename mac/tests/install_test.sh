#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
MAC_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/caffeinate-switch-install-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home with spaces & \"double quotes\" 'single quotes' \\backslash"
export BUILD_ROOT="$TEST_ROOT/build root"

rendered_plist="$TEST_ROOT/rendered.plist"
bash "$MAC_DIR/scripts/install.sh" --dry-run > "$rendered_plist"

expected_executable="$HOME/Applications/Caffeinate Switch.app/Contents/MacOS/CaffeinateSwitchApp"
plutil -lint "$rendered_plist"
[ "$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$rendered_plist")" = "$expected_executable" ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :RunAtLoad' "$rendered_plist")" = 'true' ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :KeepAlive' "$rendered_plist")" = 'false' ]

test ! -e "$HOME/Applications/Caffeinate Switch.app"
test ! -e "$HOME/Library/LaunchAgents/com.zachking.CaffeinateSwitch.plist"
test ! -e "$HOME"

echo "PASS: install dry run renders a valid launch agent without mutation"
