# Caffeinate Switch

A USB desk rocker switch that asks a Mac menu-bar agent to own one
`caffeinate` process. The ESP32-S3 reports the physical switch state over USB
CDC; the amber steam LED becomes solid only after the Mac confirms the owned
process is running.

Read [the wiring and power-safety guide](docs/wiring.md) before connecting the
board, [the printing and assembly guide](docs/printing.md) before producing the
enclosure, and [the hardware checklist](docs/testing.md) before relying on the
switch. The serial contract is in [protocol/PROTOCOL.md](protocol/PROTOCOL.md).

## Build and test

From the repository root:

```bash
make test
make firmware
make app
make stl
```

`make test` runs the SwiftPM XCTest suite when Swift is installed, PlatformIO
native tests, installer tests, and CAD checks. `make firmware` compiles the
ESP32-S3 image; `make app` creates `build/Caffeinate Switch.app`; and `make
stl` exports the four parts to `build/stl/`. None of these targets flashes a
board, installs a login item, or launches the application.

PlatformIO and OpenSCAD are optional local tools. When either is unavailable,
the corresponding target prints `SKIP:` with the reason and exits successfully;
it never reports a skipped check as a pass. CAD source checks still run without
OpenSCAD. On a host where SwiftPM's compiler and SDK do not match, the Makefile
first runs SwiftPM, then prints a documented Swift test `SKIP:` only for the
known PackageDescription/compiler-SDK incompatibility; every other Swift test
failure fails `make`. `make app` still uses a compatible-SDK direct build.

To perform actions that change a device or the Mac, run them explicitly after a
successful build:

```bash
# Flash only the selected, connected ESP32-S3 board.
cd firmware && pio run -e esp32-s3-devkitc-1 -t upload

# Build and manage the per-user menu-bar application and LaunchAgent.
bash mac/scripts/build-app.sh
bash mac/scripts/install.sh
bash mac/scripts/uninstall.sh
```

The normal macOS scripts use SwiftPM and place the application in
`~/Applications`; install also registers only
`com.zachking.CaffeinateSwitch.plist` as a login LaunchAgent. See
[docs/printing.md](docs/printing.md) for the serial-device override and the
complete setup sequence.
