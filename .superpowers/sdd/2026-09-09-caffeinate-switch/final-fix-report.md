# Final fix-wave report

Date: 2026-09-09

Review package: `review-a09296f..5751651.diff`

Worktree: `.worktrees/implementation`

## Completed fixes

- Firmware now tracks USB CDC connect and disconnect events. Disconnect clears
  stale output/confirmation, disconnected and awaiting-ACK states pulse, and a
  reconnect sends `HELLO` plus the stable physical state and keeps pulsing until
  the matching ACK. Native regressions cover disconnect, stale ACK rejection,
  reconnect, and re-confirmation.
- The shell now subtracts a real optical window between the LED chamber and the
  insert rear face. Its dimensions preserve the configured perimeter baffle.
  The no-OpenSCAD cross-section test proves that the aperture spans the gap and
  retains side/top/bottom baffles. The steam-track base seal now derives its Y,
  depth, width, and height from track/insert geometry rather than literals.
- Unexpected process termination delivery is generation-filtered before both
  state and unexpected-exit callbacks, with a second check after the state
  observer. `Reconciler.childExited()` also ignores callbacks while a
  replacement is running. Ordering regressions cover an old exit delivered
  after replacement-running state.
- Wire-record ingress now catches the dedicated unsupported-version parse error
  and emits `ERROR 0 VERSION` instead of discarding it. Firmware accepts that
  sequence-zero session error after its physical sequence advances and displays
  the rapid error blink. Both sides have focused regressions, and the protocol
  document records sequence-zero semantics.
- The direct `make app` build now always targets host-architecture macOS 13.0,
  independent of SDK version. Every invocation builds SwitchCore in a fresh
  temporary directory, eliminating stale module/library reuse across source,
  compiler, SDK, or architecture changes. The build inspects `LC_BUILD_VERSION`
  with `otool` when available and fails unless `minos` is `13.0`. A fake-SDK
  regression seeds the former stale cache, runs twice, verifies two fresh core
  compilations per run, checks both `-target` arguments, and exercises the load
  command gate.
- Install and uninstall share guarded LaunchAgent bootout logic. Only
  launchctl's not-loaded status (3) is ignored; every other bootout failure
  aborts. A post-bootout `launchctl print` check aborts before files are replaced
  or removed if the job remains loaded. Regressions cover not-loaded, success,
  arbitrary failure, and success-with-job-still-loaded.

## Verification run

### `make test`

Exit: 0.

- PASS: installer dry-run rendering and no-mutation check.
- PASS: failed staged copies preserve existing bundles.
- PASS: guarded launchctl behavior.
- PASS: CAD source interface and numeric cross-section checks, including the
  framed optical opening, 1.2 mm default baffles, and derived base seal.
- PASS: direct-build macOS 13.0 target, fresh SwitchCore builds on two
  consecutive invocations, and simulated `otool` load-command validation.
- SKIP: SwiftPM XCTest execution. The installed Swift compiler and macOS SDK
  have an existing PackageDescription/compiler-SDK mismatch.
- SKIP: PlatformIO native firmware tests. `pio` is not installed.
- SKIP: OpenSCAD render/manifold tests. `openscad` is not installed.

### Additional checks

```text
make regression-test
  PASS: all six injected Make target failures propagated without false PASS

clang++ -std=c++17 -Ifirmware/include -c firmware/src/SwitchController.cpp ...
  exit 0

swiftc -frontend -parse <changed Swift sources and regressions>
  exit 0

bash -n <CAD/mac scripts and tests> && git diff --check
  exit 0
```

Focused CAD, direct-build, installer, staged-replacement, and launchctl tests
were also run independently and passed before the full run.

## Remaining limitations and manual concerns

- Firmware Unity tests and the ESP32-S3 Arduino build still need PlatformIO on
  a matching host. The Arduino CDC event constants and hardware behavior were
  not compiled or exercised here; only the hardware-independent controller was
  compiled directly.
- Swift XCTest and a real app binary could not be produced with this host's
  mismatched compiler/SDK. Consequently, a real Mach-O `LC_BUILD_VERSION` was
  not inspected; the command construction and enforcement were tested with the
  deterministic fake toolchain. Re-run `make test` and `make app` with a
  matching Xcode toolchain.
- OpenSCAD was unavailable, so shell rendering, STL manifold checks, and a
  visual/sliced cross-section remain outstanding. The source/numeric geometry
  assertions pass, but the enclosure should still be rendered and inspected
  before printing.
- No physical hardware/manual acceptance was possible: USB unplug/replug LED
  timing, real `launchctl` replacement of a loaded job, optical illumination and
  leakage, fit, thermals, board pins, and the ten-second process grace path all
  remain on the documented hardware checklist.
