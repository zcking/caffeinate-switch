#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/caffeinate-switch-direct-build-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

FAKE_BIN="$TEST_ROOT/fake-bin"
FAKE_SDK="$TEST_ROOT/MacOSX26.5.sdk"
BUILD_ROOT="$TEST_ROOT/build root"
SWIFTC_LOG="$TEST_ROOT/swiftc.log"
mkdir -p "$FAKE_BIN" "$FAKE_SDK" "$BUILD_ROOT/.swift-sdk-26.5"
touch "$FAKE_SDK/SDKSettings.plist"

# Seed the old cache shape to prove pre-existing modules cannot suppress a
# current SwitchCore compile.
printf 'stale module\n' > "$BUILD_ROOT/.swift-sdk-26.5/SwitchCore.swiftmodule"
printf 'stale library\n' > "$BUILD_ROOT/.swift-sdk-26.5/libSwitchCore.a"

cat > "$FAKE_BIN/xcrun" <<'EOF'
#!/usr/bin/env bash
test "${1:-}" = '--show-sdk-path'
printf '%s\n' "$FAKE_SDK"
EOF

cat > "$FAKE_BIN/swiftc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'CALL\n' >> "$FAKE_SWIFTC_LOG"
output=''
module=''
previous=''
for argument in "$@"; do
    printf '%s\n' "$argument" >> "$FAKE_SWIFTC_LOG"
    case "$previous" in
        -o) output="$argument" ;;
        -emit-module-path) module="$argument" ;;
    esac
    previous="$argument"
done
for artifact in "$module" "$output"; do
    if [ -n "$artifact" ]; then
        mkdir -p "$(dirname -- "$artifact")"
        printf 'fresh artifact\n' > "$artifact"
    fi
done
if [ -n "$output" ]; then chmod +x "$output"; fi
EOF

cat > "$FAKE_BIN/otool" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' \
    'Load command 1' \
    '      cmd LC_BUILD_VERSION' \
    '  cmdsize 32' \
    ' platform 1' \
    '    minos 13.0' \
    '      sdk 26.5'
EOF
chmod +x "$FAKE_BIN/xcrun" "$FAKE_BIN/swiftc" "$FAKE_BIN/otool"

run_build() {
    PATH="$FAKE_BIN:$PATH" \
    FAKE_SDK="$FAKE_SDK" \
    FAKE_SWIFTC_LOG="$SWIFTC_LOG" \
        make --no-print-directory -C "$REPO_ROOT" app \
            SWIFTC="$FAKE_BIN/swiftc" \
            XCRUN="$FAKE_BIN/xcrun" \
            OTOOL="$FAKE_BIN/otool" \
            BUILD_ROOT="$BUILD_ROOT"
}

assert_fresh_targeted_build() {
    local arch call_count target_count
    arch="$(uname -m)"
    call_count="$(grep -c '^CALL$' "$SWIFTC_LOG")"
    target_count="$(grep -Fxc -- "$arch-apple-macosx13.0" "$SWIFTC_LOG")"
    [ "$call_count" -eq 2 ]
    [ "$target_count" -eq 2 ]
    grep -Fq 'mac/CaffeinateSwitch/Sources/SwitchCore/Reconciler.swift' "$SWIFTC_LOG"
    if grep -Fq -- "$arch-apple-macosx26.5" "$SWIFTC_LOG"; then
        echo 'FAIL: direct build used the SDK version as its deployment target' >&2
        exit 1
    fi
}

run_build
assert_fresh_targeted_build
test -x "$BUILD_ROOT/Caffeinate Switch.app/Contents/MacOS/CaffeinateSwitchApp"

# A second invocation must compile SwitchCore again even though the first one
# produced complete artifacts.
: > "$SWIFTC_LOG"
run_build
assert_fresh_targeted_build

echo 'PASS: direct builds target macOS 13.0 and rebuild SwitchCore every time'
