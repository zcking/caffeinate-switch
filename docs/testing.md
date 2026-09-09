# Hardware acceptance checklist

Complete this after firmware upload, app build, and loose-wire verification.
Keep a terminal available for `pgrep -fl caffeinate` and record any board pin
or enclosure USB-fit changes before the final shell is printed.

## LED and switch behavior

- [ ] With the Mac agent disconnected, or while a new `STATE` is awaiting an
  acknowledgement, the amber LED slowly pulses (roughly a two-second cycle).
- [ ] Turn the rocker on and wait for the Mac confirmation: the LED is solid
  amber and the agent owns one plain `/usr/bin/caffeinate` child.
- [ ] Turn the rocker off and wait for confirmation: the LED is off and that
  owned child is gone.
- [ ] Verify the error indication: after noting the latest `STATE <sequence>`
  from a serial monitor, send `ERROR <sequence> TEST` to the board. The LED
  rapidly blinks (125 ms on/off). Restore normal operation by reconnecting the
  agent and toggling the rocker so it receives a new matching acknowledgement.
- [ ] Toggle the rocker rapidly several times. After debounce, the final
  physical position is the state sent to the Mac and the LED reflects only its
  acknowledged result.

## Process ownership and reconnection

- [ ] With the rocker on, quit and restart the menu-bar agent. It reconnects,
  receives the current physical rocker state, and resynchronizes rather than
  trusting a stale LED state.
- [ ] Start an unrelated `caffeinate` manually in another terminal. Turn this
  project's rocker off; only the agent-owned child stops and the unrelated
  process survives.
- [ ] With this project's rocker on, unplug USB and time the cleanup. The
  owned child remains for nearly 10 seconds, then stops if the device has not
  returned and resynchronized.
- [ ] Repeat unplugging but reconnect before 10 seconds. Confirm the agent
  receives the current rocker state and keeps/reconciles the child without the
  old deadline stopping it.
- [ ] Unplug past 10 seconds, then reconnect. Confirm the current rocker
  position is sent again; ON starts a new owned child and OFF leaves none.

## Login and release checks

- [ ] Install explicitly with `bash mac/scripts/install.sh`, log out and back
  in (or reboot), and confirm the menu-bar agent starts at login and reconnects
  to the board.
- [ ] Confirm the fitted rocker, USB cable, LED, and board have clearance after
  closing the base; no wire crosses a vent or a screw boss.
- [ ] Before printing the final shell, write any board-specific GPIO correction
  in `firmware/include/Config.h` and any measured USB/rocker correction in the
  OpenSCAD parameters. Rebuild firmware and re-export the STLs after changes.

If a check fails, disconnect USB before rewiring. Do not use the appliance to
prevent sleep until the ownership and 10-second cleanup checks pass.
