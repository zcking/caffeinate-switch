#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
MAC_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/caffeinate-switch-launchctl-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

FAKE_BIN="$TEST_ROOT/fake-bin"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/launchctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_LAUNCHCTL_LOG"
case "${1:-}" in
    bootout)
        case "$FAKE_LAUNCHCTL_MODE" in
            not-loaded) exit 3 ;;
            bootout-error)
                echo 'Boot-out failed: 5: Input/output error' >&2
                exit 5
                ;;
            success|remains-loaded) exit 0 ;;
        esac
        ;;
    print)
        if [ "$FAKE_LAUNCHCTL_MODE" = 'remains-loaded' ]; then
            exit 0
        fi
        exit 113
        ;;
esac
exit 64
EOF
chmod +x "$FAKE_BIN/launchctl"

run_case() {
    local name="$1"
    local mode="$2"
    local expected="$3"
    local case_root="$TEST_ROOT/$name"
    local home="$case_root/home"
    local app="$home/Applications/Caffeinate Switch.app"
    local plist="$home/Library/LaunchAgents/com.zachking.CaffeinateSwitch.plist"
    local log="$case_root/launchctl.log"
    local output="$case_root/output.log"
    local status=0

    mkdir -p "$app" "$(dirname -- "$plist")"
    printf 'installed app\n' > "$app/marker"
    printf 'installed plist\n' > "$plist"

    PATH="$FAKE_BIN:$PATH" \
    HOME="$home" \
    FAKE_LAUNCHCTL_MODE="$mode" \
    FAKE_LAUNCHCTL_LOG="$log" \
        bash "$MAC_DIR/scripts/uninstall.sh" > "$output" 2>&1 || status=$?

    if [ "$expected" = 'success' ]; then
        [ "$status" -eq 0 ]
        test ! -e "$app"
        test ! -e "$plist"
    else
        [ "$status" -ne 0 ]
        test -e "$app/marker"
        test -e "$plist"
    fi

    grep -Fq "bootout gui/$(id -u)/com.zachking.CaffeinateSwitch" "$log"
}

run_case not-loaded not-loaded success
run_case unload-success success success
run_case bootout-error bootout-error failure
run_case loaded-remains remains-loaded failure

echo 'PASS: launchctl ignores only not-loaded and preserves files if unload is unsafe'
