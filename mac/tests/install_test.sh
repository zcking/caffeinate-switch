#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
MAC_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/caffeinate-switch-install-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export BUILD_ROOT="$TEST_ROOT/build root"

rendered_plist="$TEST_ROOT/rendered.plist"
bash "$MAC_DIR/scripts/install.sh" --dry-run > "$rendered_plist"

expected_executable="$HOME/Applications/Caffeinate Switch.app/Contents/MacOS/CaffeinateSwitchApp"
grep -Fq "<string>$expected_executable</string>" "$rendered_plist"
grep -A1 '<key>RunAtLoad</key>' "$rendered_plist" | grep -Fq '<true/>'
grep -A1 '<key>KeepAlive</key>' "$rendered_plist" | grep -Fq '<false/>'
plutil -lint "$rendered_plist"

test ! -e "$HOME/Applications/Caffeinate Switch.app"
test ! -e "$HOME/Library/LaunchAgents/com.zachking.CaffeinateSwitch.plist"
test ! -e "$HOME"

echo "PASS: install dry run renders a valid launch agent without mutation"
