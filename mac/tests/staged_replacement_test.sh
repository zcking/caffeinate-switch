#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
MAC_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/caffeinate-switch-staged-replacement-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

FAKE_BIN="$TEST_ROOT/fake-bin"
RELEASE_BIN="$TEST_ROOT/release-bin"
mkdir -p "$FAKE_BIN" "$RELEASE_BIN"
touch "$RELEASE_BIN/CaffeinateSwitchApp"

cat > "$FAKE_BIN/swift" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" --show-bin-path "* ]]; then
    printf '%s\n' "$FAKE_SWIFT_BIN_PATH"
fi
EOF
chmod +x "$FAKE_BIN/swift"

build_root="$TEST_ROOT/build"
existing_build_app="$build_root/Caffeinate Switch.app"
mkdir -p "$existing_build_app"
printf 'previous build' > "$existing_build_app/marker"

cat > "$FAKE_BIN/cp" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$FAKE_BIN/cp"

if PATH="$FAKE_BIN:$PATH" FAKE_SWIFT_BIN_PATH="$RELEASE_BIN" BUILD_ROOT="$build_root" \
    bash "$MAC_DIR/scripts/build-app.sh"; then
    echo "FAIL: build unexpectedly succeeded with a staging copy failure" >&2
    exit 1
fi
test "$(cat "$existing_build_app/marker")" = 'previous build'
rm "$FAKE_BIN/cp"

home="$TEST_ROOT/home"
existing_installed_app="$home/Applications/Caffeinate Switch.app"
existing_installed_plist="$home/Library/LaunchAgents/com.zachking.CaffeinateSwitch.plist"
mkdir -p "$existing_installed_app"
mkdir -p "$(dirname "$existing_installed_plist")"
printf 'previous install' > "$existing_installed_app/marker"
printf 'previous plist' > "$existing_installed_plist"

cat > "$FAKE_BIN/ditto" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$FAKE_BIN/ditto"

if PATH="$FAKE_BIN:$PATH" FAKE_SWIFT_BIN_PATH="$RELEASE_BIN" BUILD_ROOT="$build_root" HOME="$home" \
    bash "$MAC_DIR/scripts/install.sh"; then
    echo "FAIL: install unexpectedly succeeded with a staging copy failure" >&2
    exit 1
fi
test "$(cat "$existing_installed_app/marker")" = 'previous install'
test "$(cat "$existing_installed_plist")" = 'previous plist'

echo "PASS: failed staging copies preserve existing bundles"
