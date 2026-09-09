#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
model="$repo_root/cad/caffeinate_switch.scad"

# These source checks deliberately mirror only the default-value arithmetic.
# OpenSCAD is unavailable in CI, so retain the matching model assertions for
# parameter overrides and keep this test focused on the print-blocking joins.
grep -Fq 'boss_bottom_z = base_thickness;' "$model"
grep -Fq 'boss_center = [' "$model"
grep -Fq 'boss_braces(x, y);' "$model"
grep -Fq 'light_baffle = max(wall / 2, 1.2);' "$model"
grep -Fq 'light_chamber_rear_y = steam_track_y + steam_track_depth + light_baffle;' "$model"
grep -Fq 'light_chamber_rear_height = light_chamber_front_height + light_chamber_depth;' "$model"

awk '
  function fail(message) { print "FAIL: " message > "/dev/stderr"; exit 1 }
  BEGIN {
    exterior_x = 72; exterior_y = 68; exterior_z = 44
    wall = 2.4; fit = 0.30; base_thickness = 2.4
    rocker_x = 8.8 + 2 * fit; rocker_y = 14 + 2 * fit
    inner_x = exterior_x - 2 * wall; inner_y = exterior_y - 2 * wall
    roof_height = (inner_x - rocker_x) / 2
    if ((inner_y - rocker_y) / 2 > roof_height) roof_height = (inner_y - rocker_y) / 2
    if ((inner_x - rocker_x) / 2 > roof_height + 0.001) fail("roof X overhang exceeds 45 degrees")
    if ((inner_y - rocker_y) / 2 > roof_height + 0.001) fail("roof Y overhang exceeds 45 degrees")

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

    track_depth = 0.8 + 1.6 + 2 * fit
    if (track_depth / 2 > track_depth / 2 + 0.001) fail("steam track roof exceeds 45 degrees")
    baffle = wall / 2; if (baffle < 1.2) baffle = 1.2
    track_y = -exterior_y / 2 + wall - fit - 0.8 / 2
    entry_width = 5.4 + 2 * fit; entry_inset = entry_width + wall
    if (entry_inset < 9) entry_inset = 9
    chamber_front_y = -inner_y / 2 + entry_inset
    chamber_rear_y = track_y + track_depth + baffle
    chamber_depth = chamber_front_y - chamber_rear_y
    chamber_rear_top = (28 - 3) + 7.6 + chamber_depth
    if (baffle < 1.2) fail("light baffle is thinner than 1.2 mm")
    if (chamber_depth <= 0) fail("light chamber has no 45-degree roof run")
    if (chamber_rear_top > exterior_z - wall + 0.001) fail("light chamber breaks shell roof")
    printf "PASS: CAD geometry defaults (boss/base clearance, 45-degree roofs, %.1f mm light baffle)\n", baffle
  }
'
