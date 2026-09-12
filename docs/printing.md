# Print, firmware, and assembly guide

## Tune the enclosure before the final print

Export the models with `make stl` (or `bash cad/export.sh` when OpenSCAD is
installed). Print `build/stl/fit-coupon.stl` first using the exact printer,
material, layer height, and slicer settings intended for the enclosure. Check
the rocker snap fit, cable overmould, panel thickness, and USB opening before
printing the shell.

If the coupon is too tight or loose, measure the actual rocker, cable, and
board, then adjust the OpenSCAD `fit`, `rocker`, `usb`, or `usb_center_z`
parameters. Also record any board-specific USB-opening correction before the
final shell. The design defaults are a 72 x 68 x 44 mm shell, a 27.2 x 51.4 mm
board (ESP32-S3 DevKitC footprint; classic DevKit V1 boards often need different
`board` / `usb` parameters), an 8.8 x 14 mm rocker, and 0.30 mm clearance per
mating side.

Print the opaque shell and base in opaque PLA so the LED pocket does not leak
light. Change to translucent PLA only for the separate steam insert. Use a
0.4 mm nozzle, 0.2 mm layers, at least three walls/perimeters, and **no
supports**:

- Shell: open bottom down, café top up.
- Base and coupon: broad face down.
- Steam insert: rectangular flange down.

The shell's support-free geometry relies on this orientation. Use short M2
screws only after checking their engagement in the base bosses.

## Firmware and Mac setup

Install PlatformIO with an ESP32 Arduino-capable environment, then build and,
only when the correct board is connected, upload with the matching environment:

```bash
cd firmware
pio test -e native
pio run -e esp32-s3-devkitc-1 -e esp32dev
pio run -e esp32-s3-devkitc-1 -t upload   # ESP32-S3 DevKitC-1
pio run -e esp32dev -t upload             # classic ESP32 DevKit / ESP-WROOM-32
```

`pio run -t upload` changes the attached board; it is intentionally not run by
any Make target. Before the first upload, check and, if needed, correct
`SWITCH_PIN` and `LED_PIN` in `firmware/include/Config.h` against the actual
board silkscreen.

Build the macOS app with `make app` or, on a normally matched Swift toolchain,
with `bash mac/scripts/build-app.sh`. To install the built app and its
per-user login LaunchAgent, run `bash mac/scripts/install.sh`; to remove only
that app and LaunchAgent, run `bash mac/scripts/uninstall.sh`. Installation is
never automatic.

The agent discovers `/dev/cu.usbmodem*` (native USB CDC) first, then common
USB-UART names such as `/dev/cu.usbserial*`. To override that selection, run:

```bash
defaults write com.zachking.CaffeinateSwitch SerialDevicePath -string /dev/cu.YOUR_DEVICE
```

Replace the example with the exact device path. Remove the override with
`defaults delete com.zachking.CaffeinateSwitch SerialDevicePath` to return to
automatic discovery.

## Final assembly order

1. With USB disconnected, wire and bench-test the board, rocker, resistor, and
   LED according to [wiring.md](wiring.md).
2. Slide the translucent steam insert upward from the open bottom, raised wisps
   facing inward.
3. Insert the amber LED into the rear of the isolated light pocket. Use a small
   amount of opaque adhesive only if needed to stop light leakage.
4. Snap the PCB onto the base's edge rails with its USB connector toward the
   rear, keeping leads away from ventilation slots and screw bosses.
5. Route the data cable through the rear opening, lower the shell over the
   populated base, and snap the rocker into the top opening.
6. Fasten the recessed base with four short M2 screws. Re-check that neither
   the cable nor the wiring is pinched.
7. Complete the hardware checklist in [testing.md](testing.md) before putting
   the appliance into daily use.
