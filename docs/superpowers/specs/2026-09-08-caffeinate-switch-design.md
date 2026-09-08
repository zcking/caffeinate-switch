# Caffeinate Switch Design

## Goal and scope

Build a USB desk appliance whose KCD1-11 rocker controls macOS `caffeinate`, with an amber-lit coffee-steam insert showing Mac-confirmed status. Deliver parametric OpenSCAD and STLs, ESP32-S3 Arduino firmware, a native Swift menu-bar agent with login startup, tests, and build instructions. Wi-Fi and Bluetooth are excluded.

## Enclosure

The café box is approximately 72 × 68 × 44 mm, with final dimensions parameterized. Its top holds the measured 8.8 × 14 mm rocker opening, its front holds three steam cutouts and a separate translucent-PLA insert, and its rear exposes USB-C. An internal light pocket limits leakage.

The opaque shell prints face-up without supports. A screw-fastened base provides access. The 27.2 × 51.4 mm board sits in edge rails, avoiding unknown mounting-hole locations. Parameters control board, rocker, USB, wall, and insert clearances.

Exports include the shell, base, steam insert, and a rocker/USB fit coupon. Print the coupon first. Defaults target a 0.4 mm nozzle, 0.2 mm layers, three perimeters, and PLA.

## Electronics and firmware

USB-C provides power and native USB CDC serial. The rocker connects a configurable safe GPIO to ground using the internal pull-up. A PWM GPIO drives one efficient amber LED through a 220–330 Ω resistor; no transistor is required.

PlatformIO firmware using Arduino debounces the rocker, announces its current physical state, sends stable changes with increasing sequence numbers, retries until acknowledged, and exchanges heartbeats. The LED is solid for confirmed-on, off for confirmed-off, slowly pulsing while disconnected or awaiting acknowledgement, and rapidly blinking for an error.

## Protocol

Communication is versioned, UTF-8, and newline-delimited:

```text
HELLO 1
STATE <sequence> ON|OFF
PING <sequence>
ACK <sequence> ON|OFF
ERROR <sequence> <code>
```

Malformed lines are ignored safely, unsupported versions fail visibly, and sequence matching prevents stale acknowledgements. Reconnection always reconciles from the physical rocker.

## macOS agent

The native Swift menu-bar agent discovers the configured USB device and owns at most one `/usr/bin/caffeinate` child. For `ON`, it starts plain `caffeinate`, verifies the child remains alive, then acknowledges on. For `OFF`, it terminates and reaps only its own child, then acknowledges off. It never uses `killall`.

The menu shows connection, switch, and process state and provides reconnect and quit actions. A LaunchAgent starts it at login. On USB loss, a 10-second grace timer begins; absent reconnection and resynchronization, the agent stops its child. Agent shutdown also cleans up its child.

## State flow and errors

```text
rocker → firmware desired state → USB → Mac agent → caffeinate child
   ↑             LED status      ← ACK/error ← verified actual state
```

The switch is desired state, the owned process is actual state, and the LED displays actual state only. Serial failures reconnect with bounded backoff. Launch failure never lights solid. Unexpected child exit reports an error. Oversized or malformed lines cannot crash either side.

## Verification

Swift unit tests cover parsing, sequencing, process transitions, ownership, reconnection, and the disconnect timer through fake serial/process adapters. Firmware tests isolate debounce and protocol state logic from GPIO and serial. Hardware checks cover LED patterns, rapid toggles, unplug/replug, agent restart, login startup, and coexistence with unrelated `caffeinate` processes.

CAD checks cover successful OpenSCAD rendering, manifold STLs, minimum walls, coupon measurements, board insertion, rocker retention, cable clearance, and light leakage.

## Build order

1. Define protocol and state-machine tests.
2. Implement and bench-test loose firmware hardware.
3. Implement and test the Swift agent and installer.
4. Verify end-to-end cleanup and resynchronization.
5. Print and measure the fit coupon.
6. Tune, export, print, and assemble the enclosure.

## Success criteria

Rocker-on starts plain `caffeinate` and lights solid amber only after confirmation. Rocker-off stops only this project's process. Disconnect cleanup occurs after 10 seconds, reconnection follows physical state, login startup works, and all parts fit a support-free single-color FDM workflow with a translucent insert.
