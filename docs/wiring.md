# Wiring and power safety

This project is low-voltage USB electronics only. Do not connect the rocker or
any enclosure wiring to mains power, a battery pack, or an external LED supply.
Disconnect USB before changing any wiring.

## Verify the board first

The firmware defaults are `SWITCH_PIN = 4` and `LED_PIN = 5` in
`firmware/include/Config.h`. Before applying power, identify the exact GPIO4,
GPIO5, and GND markings on *your* ESP32-S3 board's silkscreen and pinout.
Board revisions and vendor labels vary; do not infer a pin location from a
photograph or from the chip package. Correct `Config.h` if the board requires
different safe pins, then rebuild and reflash.

Use a known-good USB **data** cable. A charge-only cable can power the board but
cannot create the USB CDC serial device required by the Mac agent.

## Connections

With USB disconnected, make these four connections:

| From | To | Notes |
| --- | --- | --- |
| One switched rocker terminal | ESP32-S3 GPIO4 | The firmware enables its internal pull-up. |
| The other switched rocker terminal | ESP32-S3 GND | The ON input is grounded. |
| ESP32-S3 GPIO5 | 220–330 ohm resistor, then LED anode | The resistor must be in series with the LED. |
| LED cathode | ESP32-S3 GND | Do not connect the LED directly across GPIO and ground. |

For a bare 5 mm LED, the anode is normally the longer lead and the cathode is
normally the shorter lead with the flat side of the rim. Confirm against the
LED's data sheet; lead length is not reliable after trimming. If it does not
light during the LED test, disconnect USB and check polarity, resistor value,
and the GPIO5 silkscreen mapping rather than bypassing the resistor.

Use only the two terminals that are switched by the KCD1-11 rocker. Verify
continuity with a meter before wiring because illuminated or multi-terminal
variants can have different terminal arrangements. Keep exposed leads insulated
and clear of the USB connector, screw bosses, ventilation slots, and base edge.

## First powered check

1. Keep the board out of the printed enclosure and connect it with the data
   cable.
2. Confirm macOS creates a `/dev/cu.usbmodem*` device (or identify the intended
   `/dev/cu.*` path).
3. Start the agent only after the board enumerates, then turn the rocker on and
   off. The LED must be solid only after an acknowledgement; see the four
   expected LED states in [testing.md](testing.md).
4. If the serial device name is not automatically selected, set the app's
   `SerialDevicePath` preference as described in [printing.md](printing.md).
