# Caffeinate Switch enclosure

This OpenSCAD model produces the printable café-box shell, recessed base,
translucent steam insert, and a combined rocker/USB fit coupon. Dimensions are
in millimetres and defaults target a 0.4 mm nozzle, 0.2 mm layers, three
perimeters, and PLA.

## Export

Install OpenSCAD, then run:

```bash
bash cad/tests/render_test.sh
bash cad/export.sh
```

Exports are written to the ignored `build/stl/` directory. To preview one part:

```bash
openscad -D 'part="shell"' cad/caffeinate_switch.scad
```

The `part` selector accepts `shell`, `base`, `steam`, or `coupon`.

## Parameters and measured fits

The principal defaults are:

| Parameter | Default | Purpose |
| --- | ---: | --- |
| `exterior` | `[72, 68, 44]` | finished shell width, depth, height |
| `wall` | `2.4` | nominal walls, top, and recessed base thickness |
| `fit` | `0.30` | clearance per mating side |
| `board_fit` | `0.80` | PCB rail clearance per side |
| `board` | `[27.2, 51.4]` | PCB width and length |
| `rocker` | `[8.8, 14]` | measured rocker body |
| `usb` | `[13, 10]` | support-free cable opening envelope |
| `usb_center_z` | `10.5` | rear cable opening centre above the base |

Openings add `fit` on every side, so the default rocker aperture is 9.4 ×
14.6 mm and the widest USB aperture is 13.6 mm. Print `fit-coupon.stl` first.
It is exactly 3 mm thick and puts both production openings in one small plate,
allowing the rocker snap fit, cable-overmould access, shrinkage, hole width,
and printed panel thickness to be checked before committing to the shell.
The PCB rails use the independent `board_fit` value, so tuning board retention
does not alter the proven rocker, USB, base, or steam-insert fits. Override
`fit`, `board_fit`, `rocker`, `usb`, or `usb_center_z` from the command line after
measuring the coupon and actual hardware.

## Print orientation

- Print the shell on its open bottom, with the café top facing up. The hidden
  roof tapers at 45 degrees or less to the rocker opening. The USB port has a
  45-degree roof, as do the LED chamber, insert track, and PCB retaining clips.
  The narrow curved steam details require only short wall-thickness bridges.
- Print the base broad face down. Four M2 clearance holes align with 1.65 mm
  self-tapping pilot holes in 7.6 mm bosses. Use short M2 screws and verify
  engagement depth before tightening.
- Print the steam insert rectangular flange down in translucent PLA. Its
  visible mask is 1.6 mm thick above a 0.8 mm retaining flange.
- Print the coupon broad face down using the same material, layer height, and
  slicer settings intended for the shell.

## Assembly

1. Slide the steam insert upward from the open bottom in the narrow track
   behind the front face, with its raised wisps facing inward. The top of the
   track locates it; the installed base closes the track and retains it.
2. Push a 5 mm amber LED from the main cavity into the self-supporting opening
   at the rear of the isolated light pocket. A framed optical aperture opens
   the chamber onto the insert rear face while retaining at least 1.2 mm of
   opaque perimeter baffle. The LED body plugs the only light path into the
   main cavity; use a small amount of opaque adhesive if needed.
3. Snap the PCB downward between the two segmented edge rails on the base, USB
   connector toward the rear. Independent 9 mm clips flex more readily than a
   long rigid rail, while four pads set the PCB height without depending on
   unknown mounting-hole positions.
4. Route the USB cable through the rear house-shaped opening, lower the shell
   over the populated base, install the rocker from the top, and fasten the
   recessed base with four short M2 screws.

The base includes four ventilation slots. Keep wires clear of those slots and
of the screw bosses. Board connector placement and rocker clip dimensions vary
between vendors; always verify the coupon and a board dry-fit before a final
print.
