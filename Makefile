SHELL := /bin/bash

SWIFT ?= swift
SWIFTC ?= swiftc
XCRUN ?= xcrun
PIO ?= pio
OPENSCAD ?= openscad
OTOOL ?= otool
BUILD_ROOT ?= build
CAD_TEST ?= cad/tests/render_test.sh
CAD_EXPORT ?= cad/export.sh
INSTALL_TEST ?= mac/tests/install_test.sh
STAGED_REPLACEMENT_TEST ?= mac/tests/staged_replacement_test.sh
DIRECT_BUILD_TEST ?= mac/tests/direct_build_test.sh
LAUNCHCTL_TEST ?= mac/tests/launchctl_test.sh

.PHONY: test swift-test firmware-test installer-test cad-test app-build-test firmware app stl regression-test

test: swift-test firmware-test installer-test cad-test app-build-test
	@echo "PASS: all available test targets completed; inspect any SKIP lines above."

# Run SwiftPM whenever it is present. Only this host's known PackageDescription
# compiler/SDK incompatibility is allowed to become a documented SKIP.
swift-test:
	@if ! command -v "$(SWIFT)" >/dev/null 2>&1; then echo "SKIP: Swift is not installed; XCTest suite was not run."; exit 0; fi; \
	tmp="$$(mktemp -d "$${TMPDIR:-/tmp}/caffeinate-switch-swift-test.XXXXXX")"; trap 'rm -rf "$$tmp"' EXIT; \
	if output="$$(cd mac/CaffeinateSwitch && CLANG_MODULE_CACHE_PATH="$$tmp/module-cache" "$(SWIFT)" test 2>&1)"; then \
		printf '%s\n' "$$output"; echo "PASS: SwiftPM XCTest suite."; \
	else \
		status=$$?; printf '%s\n' "$$output" >&2; \
		if [[ "$$output" == *"PackageDescription.Package.__allocating_init"* || "$$output" == *"SDK is not supported by the compiler"* ]]; then \
			echo "SKIP: SwiftPM XCTest suite is blocked by the known PackageDescription/compiler-SDK incompatibility; use a matching Xcode toolchain."; \
		else \
			echo "FAIL: SwiftPM XCTest suite failed for a reason other than the documented host incompatibility." >&2; exit "$$status"; \
		fi; \
	fi

firmware-test:
	@set -e; if ! command -v "$(PIO)" >/dev/null 2>&1; then echo "SKIP: PlatformIO is not installed; firmware native tests were not run."; exit 0; fi; \
	(cd firmware && "$(PIO)" test -e native); \
	echo "PASS: PlatformIO native firmware tests."

installer-test:
	@bash "$(INSTALL_TEST)"
	@bash "$(STAGED_REPLACEMENT_TEST)"
	@bash "$(LAUNCHCTL_TEST)"
	@echo "PASS: installer tests."

cad-test:
	@bash "$(CAD_TEST)"
	@echo "PASS: CAD source validation completed; renderer status is reported above."

app-build-test:
	@bash "$(DIRECT_BUILD_TEST)"
	@echo "PASS: direct app-build regressions."

firmware:
	@set -e; if ! command -v "$(PIO)" >/dev/null 2>&1; then echo "SKIP: PlatformIO is not installed; ESP32 firmware was not built."; exit 0; fi; \
	(cd firmware && "$(PIO)" run -e esp32-s3-devkitc-1 -e esp32dev); \
	echo "PASS: ESP32-S3 and ESP32 firmware builds completed (not flashed)."

app:
	@set -e; if ! command -v "$(SWIFTC)" >/dev/null 2>&1 || ! command -v "$(XCRUN)" >/dev/null 2>&1; then echo "SKIP: macOS app build requires swiftc and xcrun."; exit 0; fi; \
	sdk="$$("$(XCRUN)" --show-sdk-path 2>/dev/null || true)"; \
	if [[ -z "$$sdk" || ! -f "$$sdk/SDKSettings.plist" ]]; then echo "SKIP: macOS app build requires a macOS SDK discoverable by xcrun."; exit 0; fi; \
	arch="$$(uname -m)"; target="$$arch-apple-macosx13.0"; build_root="$(BUILD_ROOT)"; app="$$build_root/Caffeinate Switch.app"; \
	mkdir -p "$$build_root" "$$app/Contents/MacOS" "$$app/Contents/Resources"; \
	cache="$$(mktemp -d "$$build_root/.swift-direct.XXXXXX")"; trap 'rm -rf "$$cache"' EXIT; mkdir -p "$$cache/module-cache"; \
	"$(SWIFTC)" -target "$$target" -sdk "$$sdk" -module-cache-path "$$cache/module-cache" -parse-as-library -emit-library -static -emit-module -module-name SwitchCore mac/CaffeinateSwitch/Sources/SwitchCore/Interfaces.swift mac/CaffeinateSwitch/Sources/SwitchCore/ProtocolMessage.swift mac/CaffeinateSwitch/Sources/SwitchCore/Reconciler.swift -emit-module-path "$$cache/SwitchCore.swiftmodule" -o "$$cache/libSwitchCore.a"; \
	"$(SWIFTC)" -target "$$target" -sdk "$$sdk" -module-cache-path "$$cache/module-cache" -I "$$cache" -L "$$cache" -lSwitchCore mac/CaffeinateSwitch/Sources/CaffeinateSwitchApp/AppDelegate.swift mac/CaffeinateSwitch/Sources/CaffeinateSwitchApp/CaffeinateProcess.swift mac/CaffeinateSwitch/Sources/CaffeinateSwitchApp/DeviceDiscovery.swift mac/CaffeinateSwitch/Sources/CaffeinateSwitchApp/SerialConnection.swift mac/CaffeinateSwitch/Sources/CaffeinateSwitchApp/main.swift -o "$$app/Contents/MacOS/CaffeinateSwitchApp" -framework AppKit; \
	cp mac/Resources/Info.plist "$$app/Contents/Info.plist"; \
	plutil -lint "$$app/Contents/Info.plist"; \
	if command -v "$(OTOOL)" >/dev/null 2>&1; then \
		minos="$$($(OTOOL) -l "$$app/Contents/MacOS/CaffeinateSwitchApp" | awk '$$1 == "cmd" && $$2 == "LC_BUILD_VERSION" { in_build = 1; next } in_build && $$1 == "minos" { print $$2; exit }')"; \
		if [[ "$$minos" != "13.0" ]]; then echo "FAIL: app load command reports macOS minimum '$${minos:-missing}', expected 13.0." >&2; exit 1; fi; \
		echo "PASS: app load command targets macOS 13.0."; \
	else echo "SKIP: otool is unavailable; app load-command minimum was not inspected."; fi; \
	echo "PASS: built $$app for macOS 13.0 (not installed)."

stl:
	@set -e; if ! command -v "$(OPENSCAD)" >/dev/null 2>&1; then echo "SKIP: OpenSCAD is not installed; STL export was not run."; exit 0; fi; \
	bash "$(CAD_EXPORT)"; \
	echo "PASS: STL export completed (no printer action performed)."

# Regression coverage for the PASS-after-failure bugs. Each injected command is
# present but fails; the target must return nonzero and must not print PASS.
regression-test:
	@set -e; tmp="$$(mktemp -d "$${TMPDIR:-/tmp}/caffeinate-switch-make-regression.XXXXXX")"; trap 'rm -rf "$$tmp"' EXIT; \
	printf '%s\n' '#!/bin/bash' 'exit 1' > "$$tmp/fail"; chmod +x "$$tmp/fail"; \
	check_failure() { target="$$1"; shift; if "$(MAKE)" --no-print-directory "$$target" "$$@" > "$$tmp/$$target.out" 2>&1; then echo "FAIL: $$target unexpectedly succeeded" >&2; return 1; fi; if grep -q '^PASS:' "$$tmp/$$target.out"; then echo "FAIL: $$target printed PASS after failure" >&2; return 1; fi; echo "PASS: $$target failure propagates without PASS"; }; \
	check_failure firmware PIO=false; \
	check_failure firmware-test PIO=false; \
	check_failure app SWIFTC=false; \
	check_failure stl OPENSCAD=true CAD_EXPORT="$$tmp/fail"; \
	check_failure installer-test INSTALL_TEST="$$tmp/fail"; \
	check_failure cad-test CAD_TEST="$$tmp/fail"
