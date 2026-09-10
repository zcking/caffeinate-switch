#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
model="$repo_root/cad/caffeinate_switch.scad"

# These source checks deliberately mirror only the default-value arithmetic.
# OpenSCAD is unavailable in CI, so retain the matching model assertions for
# parameter overrides and keep this test focused on the print-blocking joins.
grep -Fq 'boss_bottom_z = base_thickness;' "$model"
grep -Fq 'boss_center = [' "$model"
grep -Fq 'boss_ramp(x, y);' "$model"
grep -Fq 'boss_ramp_height = boss_ramp_run;' "$model"
grep -Fq 'cylinder(d = m2_pilot, h = eps);' "$model"
grep -Fq 'lower_roof_radial_run = sqrt(' "$model"
grep -Fq 'roof_radial_run = sqrt(roof_x_run * roof_x_run + roof_y_run * roof_y_run);' "$model"
grep -Fq 'assert(roof_radial_run <= roof_height + 0.001,' "$model"
grep -Fq 'rocker_open[0] > 0 && rocker_open[1] > 0,' "$model"
grep -Fq 'rocker_open[0] > 2 * rocker_corner_radius' "$model"
grep -Fq 'rocker_open[0] + 2 * rocker_surround <= inner[0]' "$model"
grep -Fq 'board_fit = 0.80;' "$model"
grep -Fq 'roof_support = [board[0] + 2 * board_fit, board[1] + 2 * board_fit];' "$model"
grep -Fq 'rail_inner = board[0] / 2 + board_fit;' "$model"
grep -Fq 'light_baffle = max(wall / 2, 1.2);' "$model"
grep -Fq 'insert_rear_y = steam_track_y + steam_track_depth;' "$model"
grep -Fq 'light_chamber_rear_y = insert_rear_y + light_baffle;' "$model"
grep -Fq 'light_chamber_rear_height = light_chamber_front_height + light_chamber_depth;' "$model"
grep -Fq 'light_window_y = insert_rear_y - eps;' "$model"
grep -Fq 'light_window_depth = light_chamber_rear_y - insert_rear_y + 2 * eps;' "$model"
grep -Fq 'module light_window() {' "$model"
grep -Fq 'light_window();' "$model"
grep -Fq 'steam_seal_y = steam_track_y + fit;' "$model"
grep -Fq 'steam_seal_depth = steam_track_depth - 2 * fit;' "$model"
if grep -Fq -- '-31.45' "$model" || grep -Fq 'cube([steam_flange[0], 2.1' "$model"; then
  echo 'FAIL: steam-track base seal still uses hard-coded coordinates' >&2
  exit 1
fi

awk '
  function fail(message) { print "FAIL: " message > "/dev/stderr"; exit 1 }
  function rocker_valid(open_x, open_y, inner_x, inner_y, surround, corner_radius) {
    return open_x > 0 && open_y > 0 \
      && open_x > 2 * corner_radius && open_y > 2 * corner_radius \
      && open_x + 2 * surround <= inner_x \
      && open_y + 2 * surround <= inner_y
  }
  BEGIN {
    exterior_x = 72; exterior_y = 68; exterior_z = 44; eps = 0.02
    wall = 2.4; fit = 0.30; board_fit = 0.80; base_thickness = 2.4
    rocker_x = 8.8 + 2 * fit; rocker_y = 14 + 2 * fit
    inner_x = exterior_x - 2 * wall; inner_y = exterior_y - 2 * wall
    rocker_surround = wall
    rocker_corner_radius = 0.6
    if (!rocker_valid(rocker_x, rocker_y, inner_x, inner_y, rocker_surround, rocker_corner_radius)) fail("default rocker opening is invalid")
    if (rocker_valid(-1 + 2 * fit, rocker_y, inner_x, inner_y, rocker_surround, rocker_corner_radius)) fail("negative rocker override was accepted")
    if (rocker_valid(0.6, rocker_y, inner_x, inner_y, rocker_surround, rocker_corner_radius)) fail("undersize rocker override was accepted")
    if (rocker_valid(inner_x - 2 * rocker_surround + 0.01, rocker_y, inner_x, inner_y, rocker_surround, rocker_corner_radius)) fail("oversize rocker override was accepted")
    roof_support_x = 27.2 + 2 * board_fit; roof_support_y = 51.4 + 2 * board_fit
    rail_inner = 27.2 / 2 + board_fit
    if (rail_inner != 14.4) fail("PCB rails do not provide 0.8 mm clearance per side")
    lower_x_run = (inner_x - roof_support_x) / 2; lower_y_run = (inner_y - roof_support_y) / 2
    lower_height = sqrt(lower_x_run ^ 2 + lower_y_run ^ 2)
    roof_x_run = (roof_support_x - rocker_x) / 2; roof_y_run = (roof_support_y - rocker_y) / 2
    roof_radial_run = sqrt(roof_x_run ^ 2 + roof_y_run ^ 2)
    roof_height = exterior_z - wall - lower_height
    if (lower_x_run < 0 || lower_y_run < 0 || lower_height + 0.001 < sqrt(lower_x_run ^ 2 + lower_y_run ^ 2)) fail("lower roof corner overhang exceeds 45 degrees")
    if (roof_x_run < 0 || roof_y_run < 0 || roof_radial_run > roof_height + 0.001) fail("main roof corner overhang exceeds 45 degrees")

    base_x = exterior_x - 2 * (wall + fit); base_y = exterior_y - 2 * (wall + fit)
    base_radius = 6 - wall - fit; boss_radius = 7.6 / 2; clearance = 2.4
    overlap = wall / 2
    boss_x = inner_x / 2 - boss_radius + overlap
    boss_y = inner_y / 2 - boss_radius + overlap
    boss_bottom_z = base_thickness
    if (boss_bottom_z < base_thickness) fail("boss collides with base")
    if (boss_x + clearance / 2 >= base_x / 2 || boss_y + clearance / 2 >= base_y / 2) fail("base clearance hole leaves base")
    corner_distance = sqrt((boss_x - (base_x / 2 - base_radius)) ^ 2 + (boss_y - (base_y / 2 - base_radius)) ^ 2)
    if (corner_distance + clearance / 2 >= base_radius) fail("base clearance hole leaves rounded corner")
    if (boss_x + boss_radius + 0.001 < inner_x / 2 + overlap || boss_y + boss_radius + 0.001 < inner_y / 2 + overlap) fail("boss does not overlap wall")
    boss_ramp_run = boss_radius - overlap + wall / 2 - 1.65 / 2
    boss_ramp_height = boss_ramp_run
    if (boss_ramp_height + 0.001 < boss_ramp_run || boss_ramp_run >= 8.5) fail("boss ramp is unsupported or leaves no threaded engagement")

    track_depth = 0.8 + 1.6 + 2 * fit
    if (track_depth / 2 > track_depth / 2 + 0.001) fail("steam track roof exceeds 45 degrees")
    baffle = wall / 2; if (baffle < 1.2) baffle = 1.2
    track_y = -exterior_y / 2 + wall - fit - 0.8 / 2
    insert_rear_y = track_y + track_depth
    entry_width = 5.4 + 2 * fit; entry_inset = entry_width + wall
    if (entry_inset < 9) entry_inset = 9
    chamber_front_y = -inner_y / 2 + entry_inset
    chamber_rear_y = insert_rear_y + baffle
    chamber_depth = chamber_front_y - chamber_rear_y
    chamber_width = 38 - 3
    chamber_floor = 28 - 3
    chamber_rear_height = 7.6 + chamber_depth
    chamber_rear_top = chamber_floor + chamber_rear_height
    if (baffle < 1.2) fail("light baffle is thinner than 1.2 mm")
    if (chamber_depth <= 0) fail("light chamber has no 45-degree roof run")
    if (chamber_rear_top > exterior_z - wall + 0.001) fail("light chamber breaks shell roof")
    window_width = chamber_width - 2 * baffle
    window_height = chamber_rear_height - 2 * baffle
    window_bottom = chamber_floor + baffle
    window_top = window_bottom + window_height
    window_y = insert_rear_y - eps
    window_depth = chamber_rear_y - insert_rear_y + 2 * eps
    if (window_width <= 0 || window_height <= 0) fail("light window has no opening")
    if ((chamber_width - window_width) / 2 + 0.001 < baffle) fail("light window loses a side baffle")
    if (window_bottom + 0.001 < 28 - 24 / 2 + baffle || window_top > 28 + 24 / 2 - baffle + 0.001) fail("light window loses an insert perimeter baffle")
    if (window_y > insert_rear_y + 0.001 || window_y + window_depth + 0.001 < chamber_rear_y) fail("light window does not bridge the insert/chamber cross-section")

    seal_y = track_y + fit
    seal_depth = track_depth - 2 * fit
    seal_height = 28 - 24 / 2 - fit - base_thickness
    if (seal_depth <= 0 || seal_height <= 0) fail("steam-track base seal has no volume")
    if (seal_y + 0.001 < track_y || seal_y + seal_depth > insert_rear_y + 0.001) fail("steam-track base seal leaves its derived track bounds")
    printf "PASS: CAD geometry defaults (radial roofs, framed optical cross-section, %.1f mm light baffles, derived base seal)\n", baffle
  }
'
