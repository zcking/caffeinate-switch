# Caffeinate Switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a printable USB desk switch whose ESP32-S3 rocker controls a Mac-owned `caffeinate` process and whose illuminated steam insert displays confirmed process state.

**Architecture:** The ESP32-S3 publishes debounced desired state over a versioned line protocol. A Swift menu-bar application reconciles that state with one child `/usr/bin/caffeinate` process and acknowledges verified state; parametric OpenSCAD sources produce the enclosure parts and fit coupon.

**Tech Stack:** PlatformIO, Arduino/ESP32-S3, C++17, Swift 5.10/Swift Package Manager, AppKit, POSIX serial APIs, OpenSCAD, shell scripts.

**Spec:** `docs/superpowers/specs/2026-09-08-caffeinate-switch-design.md`

## Global Constraints

- Use USB CDC only; Wi-Fi and Bluetooth are out of scope.
- Use plain `/usr/bin/caffeinate` and terminate only the child process owned by this application.
- Wait 10 seconds after USB disconnect before stopping the owned process.
- Target a 27.2 × 51.4 mm ESP32-S3-WROOM development board and an 8.8 × 14 mm KCD1-11 opening.
- The opaque shell must print face-up without supports; the steam insert is separate translucent PLA.
- Print the rocker/USB fit coupon before the complete enclosure.

---

### Task 1: Repository contract and protocol library

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `protocol/PROTOCOL.md`
- Create: `mac/CaffeinateSwitch/Package.swift`
- Create: `mac/CaffeinateSwitch/Sources/SwitchCore/ProtocolMessage.swift`
- Create: `mac/CaffeinateSwitch/Tests/SwitchCoreTests/ProtocolMessageTests.swift`

**Interfaces:**
- Produces: `enum SwitchState { case on, off }`
- Produces: `enum ProtocolMessage: Equatable` with `hello(version:)`, `state(sequence:state:)`, `ping(sequence:)`, `ack(sequence:state:)`, and `error(sequence:code:)`.
- Produces: `ProtocolMessage.parse(_:) throws -> ProtocolMessage` and `var encoded: String`.

- [ ] **Step 1: Add the package skeleton and failing parser tests**

```swift
import XCTest
@testable import SwitchCore

final class ProtocolMessageTests: XCTestCase {
    func testRoundTripsEveryMessage() throws {
        let messages: [ProtocolMessage] = [
            .hello(version: 1), .state(sequence: 7, state: .on),
            .ping(sequence: 7), .ack(sequence: 7, state: .off),
            .error(sequence: 7, code: "CHILD_EXIT")
        ]
        for message in messages {
            XCTAssertEqual(try ProtocolMessage.parse(message.encoded), message)
        }
    }

    func testRejectsMalformedInput() {
        XCTAssertThrowsError(try ProtocolMessage.parse("STATE nope ON"))
        XCTAssertThrowsError(try ProtocolMessage.parse(String(repeating: "x", count: 257)))
    }
}
```

- [ ] **Step 2: Run the tests and verify the missing module failure**

Run: `cd mac/CaffeinateSwitch && swift test`

Expected: FAIL because `SwitchCore` and its protocol types do not exist.

- [ ] **Step 3: Implement strict parsing and encoding**

Implement the exact cases above, accept only protocol version `1`, require unsigned integer sequence values, limit lines to 256 bytes, and reject whitespace inside error codes. Add `protocol/PROTOCOL.md` with the five wire records, newline framing, retry behavior, and examples. Add `.gitignore` entries for `.build/`, `.pio/`, `build/`, `*.stl`, and `.DS_Store`.

- [ ] **Step 4: Verify the protocol library**

Run: `cd mac/CaffeinateSwitch && swift test`

Expected: all `ProtocolMessageTests` pass.

- [ ] **Step 5: Commit**

```bash
git add .gitignore README.md protocol mac/CaffeinateSwitch
git commit -m "feat: define serial protocol contract"
```

### Task 2: Firmware state machine

**Files:**
- Create: `firmware/platformio.ini`
- Create: `firmware/include/Config.h`
- Create: `firmware/include/SwitchController.h`
- Create: `firmware/src/SwitchController.cpp`
- Create: `firmware/src/main.cpp`
- Create: `firmware/test/test_switch_controller/test_main.cpp`

**Interfaces:**
- Produces: `enum class ConfirmedState { Unknown, Off, On, Error }`.
- Produces: `SwitchController::sample(bool grounded, uint32_t nowMs)`, `receiveLine(std::string_view)`, `tick(uint32_t)`, `takeOutbound()`, and `ledBrightness(uint32_t)`.
- Consumes: protocol version and records defined in Task 1.

- [ ] **Step 1: Write native tests for debounce, stale ACKs, and LED states**

```cpp
TEST_CASE("state changes only after 40 ms stable") {
  SwitchController c;
  c.sample(true, 0); c.sample(false, 10); c.sample(true, 20);
  CHECK(c.takeOutbound().empty());
  c.sample(true, 61);
  CHECK(c.takeOutbound() == "STATE 1 ON\n");
}

TEST_CASE("stale acknowledgement cannot confirm LED") {
  SwitchController c;
  c.sample(true, 0); c.sample(true, 41); c.takeOutbound();
  c.receiveLine("ACK 0 ON");
  CHECK(c.confirmedState() == ConfirmedState::Unknown);
}
```

- [ ] **Step 2: Run native tests and verify failure**

Run: `cd firmware && pio test -e native`

Expected: FAIL because `SwitchController` does not exist.

- [ ] **Step 3: Implement hardware-independent state logic**

Use `DEBOUNCE_MS = 40`, `RETRY_MS = 1000`, and `HEARTBEAT_MS = 3000`. Increment the sequence only on stable physical transitions. Retry the current `STATE` until a matching ACK. Render unknown as a 2-second breathing PWM curve, error as 125 ms on/off, confirmed on as 255, and confirmed off as 0.

- [ ] **Step 4: Wire Arduino adapters and configurable pins**

In `Config.h`, set safe initial defaults `SWITCH_PIN = 4`, `LED_PIN = 5`, and `SWITCH_ACTIVE_LOW = true`, with comments requiring verification against the exact dev-board pinout. In `main.cpp`, configure pull-up input, native USB CDC, PWM output, line buffering capped at 256 bytes, and call the controller from a non-blocking loop.

- [ ] **Step 5: Verify native tests and ESP32 compilation**

Run: `cd firmware && pio test -e native && pio run -e esp32-s3-devkitc-1`

Expected: tests pass and firmware compiles for `esp32-s3-devkitc-1`.

- [ ] **Step 6: Commit**

```bash
git add firmware
git commit -m "feat: add ESP32 switch firmware"
```

### Task 3: Mac reconciliation core

**Files:**
- Create: `mac/CaffeinateSwitch/Sources/SwitchCore/Reconciler.swift`
- Create: `mac/CaffeinateSwitch/Sources/SwitchCore/Interfaces.swift`
- Create: `mac/CaffeinateSwitch/Tests/SwitchCoreTests/ReconcilerTests.swift`

**Interfaces:**
- Produces: `protocol ChildProcessManaging` with `isRunning`, `start() throws`, and `stop()`.
- Produces: `protocol Scheduler` returning a cancellable token from `schedule(after:_:)`.
- Produces: `Reconciler.receive(_:)`, `serialConnected()`, `serialDisconnected()`, and callback `send: (ProtocolMessage) -> Void`.

- [ ] **Step 1: Write failing state-machine tests**

```swift
func testOnStartsChildBeforeAcknowledging() {
    let process = FakeProcess()
    let reconciler = Reconciler(process: process, scheduler: FakeScheduler())
    var sent: [ProtocolMessage] = []; reconciler.send = { sent.append($0) }
    reconciler.receive(.state(sequence: 9, state: .on))
    XCTAssertTrue(process.isRunning)
    XCTAssertEqual(sent, [.ack(sequence: 9, state: .on)])
}

func testDisconnectStopsAfterTenSecondsOnly() {
    let scheduler = FakeScheduler(); let process = FakeProcess(running: true)
    let reconciler = Reconciler(process: process, scheduler: scheduler)
    reconciler.serialDisconnected(); scheduler.advance(by: 9.9)
    XCTAssertTrue(process.isRunning)
    scheduler.advance(by: 0.1); XCTAssertFalse(process.isRunning)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `cd mac/CaffeinateSwitch && swift test --filter ReconcilerTests`

Expected: FAIL because the interfaces and reconciler do not exist.

- [ ] **Step 3: Implement deterministic reconciliation**

Start before ACK ON, stop before ACK OFF, cancel disconnect cleanup upon reconnection, schedule cleanup at exactly 10 seconds, reject unsupported hello versions with `ERROR 0 VERSION`, return `CHILD_START` on launch failure, and emit `CHILD_EXIT` when a desired-on child exits unexpectedly.

- [ ] **Step 4: Verify core behavior**

Run: `cd mac/CaffeinateSwitch && swift test`

Expected: protocol and reconciler tests pass.

- [ ] **Step 5: Commit**

```bash
git add mac/CaffeinateSwitch
git commit -m "feat: reconcile switch and caffeinate state"
```

### Task 4: Serial, process, and menu-bar application

**Files:**
- Modify: `mac/CaffeinateSwitch/Package.swift`
- Create: `mac/CaffeinateSwitch/Sources/CaffeinateSwitchApp/CaffeinateProcess.swift`
- Create: `mac/CaffeinateSwitch/Sources/CaffeinateSwitchApp/SerialConnection.swift`
- Create: `mac/CaffeinateSwitch/Sources/CaffeinateSwitchApp/DeviceDiscovery.swift`
- Create: `mac/CaffeinateSwitch/Sources/CaffeinateSwitchApp/AppDelegate.swift`
- Create: `mac/CaffeinateSwitch/Sources/CaffeinateSwitchApp/main.swift`
- Create: `mac/CaffeinateSwitch/Tests/CaffeinateSwitchAppTests/CaffeinateProcessTests.swift`

**Interfaces:**
- Consumes: `ProtocolMessage`, `Reconciler`, and `ChildProcessManaging`.
- Produces: executable product `CaffeinateSwitchApp`.
- Produces: `SerialConnection(path:onLine:onDisconnect:)`, `write(_:)`, and `close()`.

- [ ] **Step 1: Write a child ownership test**

Create a fixture executable that waits for SIGTERM, then test that `CaffeinateProcess(executableURL: fixtureURL)` starts, reports its own PID, stops, and never searches for or signals unrelated PIDs.

- [ ] **Step 2: Run the test and verify failure**

Run: `cd mac/CaffeinateSwitch && swift test --filter CaffeinateProcessTests`

Expected: FAIL because the executable target and process wrapper do not exist.

- [ ] **Step 3: Implement process and serial adapters**

Use `Process` with executable `/usr/bin/caffeinate` and no arguments. Store only that `Process` instance; terminate and wait for it on stop. Open `/dev/cu.usbmodem*` using `open`, configure raw 115200 8N1 with `termios`, read on a `DispatchSourceRead`, enforce the 256-byte line limit, and marshal callbacks to the main queue. Discover only `/dev/cu.*` candidates, with a user-default override named `SerialDevicePath`.

- [ ] **Step 4: Implement the menu-bar UI**

Use `NSStatusItem` with status text items for device, rocker, and process plus Reconnect and Quit. On quit, close serial and synchronously stop the owned child. Reconnect with exponential delays of 1, 2, 4, then 5 seconds maximum.

- [ ] **Step 5: Run tests and a manual launch**

Run: `cd mac/CaffeinateSwitch && swift test && swift run CaffeinateSwitchApp`

Expected: tests pass; a menu-bar item appears and reports disconnected when no board is attached. Quit from the menu to end the manual test.

- [ ] **Step 6: Commit**

```bash
git add mac/CaffeinateSwitch
git commit -m "feat: add native macOS menu-bar agent"
```

### Task 5: Application bundle and login installer

**Files:**
- Create: `mac/scripts/build-app.sh`
- Create: `mac/scripts/install.sh`
- Create: `mac/scripts/uninstall.sh`
- Create: `mac/Resources/Info.plist`
- Create: `mac/Resources/com.zachking.CaffeinateSwitch.plist.template`
- Create: `mac/tests/install_test.sh`

**Interfaces:**
- Consumes: release executable from Task 4.
- Produces: `build/Caffeinate Switch.app` and `~/Library/LaunchAgents/com.zachking.CaffeinateSwitch.plist`.

- [ ] **Step 1: Write a failing installer integration test**

The test sets temporary `HOME` and `BUILD_ROOT`, runs `install.sh --dry-run`, and asserts the rendered plist contains an absolute app executable path, `RunAtLoad = true`, and `KeepAlive = false`.

- [ ] **Step 2: Run it and verify failure**

Run: `bash mac/tests/install_test.sh`

Expected: FAIL because scripts and templates do not exist.

- [ ] **Step 3: Implement build/install/uninstall scripts**

Build universal-for-host release output with `swift build -c release`, assemble the `.app`, copy `Info.plist`, and render the LaunchAgent with `plutil -lint` validation. Install under `$HOME/Applications`, bootstrap with `launchctl bootstrap gui/$(id -u)`, and uninstall with `bootout` before deleting only this app and plist. Support `--dry-run` without filesystem mutation.

- [ ] **Step 4: Verify packaging**

Run: `bash mac/tests/install_test.sh && bash mac/scripts/build-app.sh && plutil -lint "build/Caffeinate Switch.app/Contents/Info.plist"`

Expected: integration test passes, app bundle exists, and plist is valid.

- [ ] **Step 5: Commit**

```bash
git add mac
git commit -m "feat: package and install macOS agent"
```

### Task 6: Parametric enclosure and STL exports

**Files:**
- Create: `cad/caffeinate_switch.scad`
- Create: `cad/export.sh`
- Create: `cad/README.md`
- Create: `cad/tests/render_test.sh`
- Generate (ignored): `build/stl/shell.stl`
- Generate (ignored): `build/stl/base.stl`
- Generate (ignored): `build/stl/steam-insert.stl`
- Generate (ignored): `build/stl/fit-coupon.stl`

**Interfaces:**
- Produces: OpenSCAD selector `part` accepting `shell`, `base`, `steam`, or `coupon`.
- Produces: parameters `board=[27.2,51.4]`, `rocker=[8.8,14]`, `wall=2.4`, `fit=0.30`, and exterior `[72,68,44]`.

- [ ] **Step 1: Write a failing render test**

```bash
for part in shell base steam coupon; do
  openscad -o "$tmp/$part.stl" -D "part=\"$part\"" cad/caffeinate_switch.scad
  test -s "$tmp/$part.stl"
  grep -q 'solid OpenSCAD_Model' "$tmp/$part.stl"
done
```

- [ ] **Step 2: Run it and verify failure**

Run: `bash cad/tests/render_test.sh`

Expected: FAIL because the OpenSCAD model does not exist (or SKIP with a clear message if OpenSCAD is not installed).

- [ ] **Step 3: Model the shell and board retention**

Create a rounded rectangular shell with 2.4 mm walls, open bottom, top rocker opening using `fit`, rear USB opening with configurable `usb_center_z`, two internal board edge rails sized from `board`, an LED pocket behind the front, and four base screw bosses sized for M2 self-tapping screws. Keep all overhangs at or below 45 degrees in face-up print orientation.

- [ ] **Step 4: Model the base, insert, and coupon**

Create a 2.4 mm recessed base with M2 clearance holes and ventilation slots. Build three connected steam wisps as a 1.6 mm translucent insert with rear retaining flange. Put rocker and USB openings into a small 3 mm-thick coupon so clearances can be measured before the full print.

- [ ] **Step 5: Export and validate all meshes**

Run: `bash cad/tests/render_test.sh && bash cad/export.sh`

Expected: four non-empty, manifold STL files appear in `build/stl/`; OpenSCAD emits no empty-object or non-manifold warnings.

- [ ] **Step 6: Commit source CAD**

```bash
git add cad
git commit -m "feat: add printable cafe enclosure"
```

### Task 7: End-to-end build and user guide

**Files:**
- Modify: `README.md`
- Create: `docs/wiring.md`
- Create: `docs/printing.md`
- Create: `docs/testing.md`
- Create: `Makefile`

**Interfaces:**
- Consumes: all firmware, Mac, and CAD deliverables.
- Produces: `make test`, `make firmware`, `make app`, and `make stl` workflows.

- [ ] **Step 1: Add build orchestration**

Define `make test` to run Swift tests, PlatformIO native tests, installer tests, and CAD render tests; define separate build targets without automatic flashing or installation.

- [ ] **Step 2: Write exact wiring and safety instructions**

Document rocker terminal-to-GPIO4 and terminal-to-GND, GPIO5-to-resistor-to-LED-anode, LED-cathode-to-GND, LED polarity identification, USB data-cable requirement, and the instruction to verify GPIO4/5 against the exact board silkscreen before applying power.

- [ ] **Step 3: Write print and setup instructions**

Document coupon-first tolerance tuning, opaque/translucent filament changes, 0.2 mm layers, three walls, no support, firmware environment setup, `pio run -t upload`, app build/install/uninstall, serial override, and assembly order.

- [ ] **Step 4: Run the full verification suite**

Run: `make test && make firmware && make app && make stl`

Expected: every installed-tool test passes and all four build products complete. Any missing optional tool must produce a clear documented skip, not a false pass.

- [ ] **Step 5: Perform the hardware checklist**

Follow `docs/testing.md`: confirm all four LED modes; rapid rocker toggles; agent restart; unrelated `caffeinate` survival; unplug cleanup at 10 seconds; reconnect before and after the deadline; current rocker resynchronization; and login startup. Record board-specific pin or USB-opening corrections in `Config.h` and OpenSCAD parameters before printing the final shell.

- [ ] **Step 6: Commit**

```bash
git add README.md Makefile docs
git commit -m "docs: add complete build and assembly guide"
```
