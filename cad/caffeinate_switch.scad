// Parametric, support-free café enclosure for Caffeinate Switch.
// Units are millimetres. Override parameters with OpenSCAD -D arguments.

part = "shell";                 // shell, base, steam, or coupon
board = [27.2, 51.4];           // PCB width, length
rocker = [8.8, 14];             // measured panel opening width, length
exterior = [72, 68, 44];        // width, depth, height
wall = 2.4;
fit = 0.30;                     // clearance on each mating side

usb_center_z = 10.5;
usb = [13, 10];                 // cable opening width and overall height
pcb_thickness = 1.6;
base_thickness = 2.4;
insert_thickness = 1.6;
flange_thickness = 0.8;
m2_pilot = 1.65;
m2_clearance = 2.4;

$fn = 48;
eps = 0.02;
outer_radius = 6;
rocker_open = [rocker[0] + 2 * fit, rocker[1] + 2 * fit];
rocker_corner_radius = 0.6;
inner = [exterior[0] - 2 * wall, exterior[1] - 2 * wall];
rocker_surround = wall;
base_size = [
    exterior[0] - 2 * (wall + fit),
    exterior[1] - 2 * (wall + fit)
];
base_radius = outer_radius - wall - fit;
boss_diameter = 7.6;
boss_radius = boss_diameter / 2;
// Put each boss partly inside the shell wall, then brace it in both directions.
boss_wall_overlap = wall / 2;
boss_center = [
    inner[0] / 2 - boss_radius + boss_wall_overlap,
    inner[1] / 2 - boss_radius + boss_wall_overlap
];
boss_bottom_z = base_thickness;
boss_height = 8.5;
boss_brace_diameter = wall;
// The ramp expands from the pilot to the furthest brace edge at 45 degrees.
boss_ramp_run = boss_radius - boss_wall_overlap + boss_brace_diameter / 2
                 - m2_pilot / 2;
boss_ramp_height = boss_ramp_run;
boss_straight_height = boss_height - boss_ramp_height;
board_top_z = 9.4;
board_bottom_z = board_top_z - pcb_thickness;
steam_center_z = 28;
steam_flange = [38, 24];
steam_track_width = steam_flange[0] + 2 * fit;
steam_track_depth = flange_thickness + insert_thickness + 2 * fit;
steam_track_y = -exterior[1] / 2 + wall - fit - flange_thickness / 2;
steam_track_top = steam_center_z + steam_flange[1] / 2 + fit;
steam_track_roof_rise = steam_track_depth / 2;
steam_track_roof_run = steam_track_depth / 2;
light_baffle = max(wall / 2, 1.2);
insert_rear_y = steam_track_y + steam_track_depth;
light_entry_size = [5.4 + 2 * fit, 5.5 + 2 * fit];
light_entry_inset = max(light_entry_size[0] + wall, 9);
light_chamber_width = steam_flange[0] - 3;
light_chamber_floor_z = steam_center_z - 3;
light_chamber_front_y = -inner[1] / 2 + light_entry_inset;
light_chamber_rear_y = insert_rear_y + light_baffle;
light_chamber_depth = light_chamber_front_y - light_chamber_rear_y;
light_chamber_front_height = 7.6;
light_chamber_rear_height = light_chamber_front_height + light_chamber_depth;
light_entry_center_z = light_chamber_floor_z + light_chamber_front_height / 2;
light_window_width = light_chamber_width - 2 * light_baffle;
light_window_height = light_chamber_rear_height - 2 * light_baffle;
light_window_bottom_z = light_chamber_floor_z + light_baffle;
light_window_y = insert_rear_y - eps;
light_window_depth = light_chamber_rear_y - insert_rear_y + 2 * eps;
steam_seal_width = steam_flange[0];
steam_seal_y = steam_track_y + fit;
steam_seal_depth = steam_track_depth - 2 * fit;
steam_seal_height = steam_center_z - steam_flange[1] / 2
                    - fit - base_thickness;
// This intermediate cavity fits the board, allowing both tapered stages to
// bound their *radial* corner run as well as their X/Y runs.
roof_support = [board[0] + 2 * fit, board[1] + 2 * fit];
lower_roof_x_run = (inner[0] - roof_support[0]) / 2;
lower_roof_y_run = (inner[1] - roof_support[1]) / 2;
lower_roof_radial_run = sqrt(
    lower_roof_x_run * lower_roof_x_run
    + lower_roof_y_run * lower_roof_y_run
);
lower_roof_height = lower_roof_radial_run;
roof_x_run = (roof_support[0] - rocker_open[0]) / 2;
roof_y_run = (roof_support[1] - rocker_open[1]) / 2;
roof_radial_run = sqrt(roof_x_run * roof_x_run + roof_y_run * roof_y_run);
roof_start_z = lower_roof_height;
roof_height = exterior[2] - wall - roof_start_z;

assert(wall >= 2.4, "wall must be at least 2.4 mm");
assert(exterior[0] > board[0] + 2 * wall);
assert(exterior[1] > board[1] + 2 * wall);
assert(rocker_open[0] > 0 && rocker_open[1] > 0,
       "rocker opening dimensions must be positive");
assert(rocker_open[0] > 2 * rocker_corner_radius
       && rocker_open[1] > 2 * rocker_corner_radius,
       "rocker opening is too small for its printable corner radius");
assert(rocker_open[0] + 2 * rocker_surround <= inner[0]
       && rocker_open[1] + 2 * rocker_surround <= inner[1],
       "rocker opening must leave printable material within the shell cavity");
assert(base_radius > 0, "base corner radius must remain positive");
assert(boss_bottom_z >= base_thickness,
       "bosses must start above the installed base");
assert(boss_center[0] + m2_clearance / 2 < base_size[0] / 2
       && boss_center[1] + m2_clearance / 2 < base_size[1] / 2,
       "base clearance holes must remain within the base");
assert(boss_center[0] + boss_radius + 0.001 >= inner[0] / 2 + boss_wall_overlap
       && boss_center[1] + boss_radius + 0.001 >= inner[1] / 2 + boss_wall_overlap,
       "bosses must overlap the shell walls");
assert(boss_ramp_height >= boss_ramp_run && boss_straight_height > 0,
       "boss ramp must be self-supporting and leave threaded engagement");
assert(roof_support[0] >= rocker_open[0] && roof_support[1] >= rocker_open[1],
       "board-clearance roof support must enclose the rocker opening");
assert(roof_start_z >= board_top_z + 1.8,
       "board clips collide with the lower tapered roof");
assert(lower_roof_x_run >= 0 && lower_roof_y_run >= 0);
assert(lower_roof_radial_run <= lower_roof_height + 0.001,
       "lower roof corner overhang exceeds 45 degrees");
assert(roof_x_run >= 0 && roof_y_run >= 0);
assert(roof_radial_run <= roof_height + 0.001,
       "main roof corner overhang exceeds 45 degrees");
assert(usb[1] + 2 * fit >= (usb[0] + 2 * fit) / 2,
       "USB opening must be tall enough for its 45-degree roof");
assert(steam_track_roof_rise <= steam_track_roof_run + 0.001,
       "steam track roof must be no steeper than 45 degrees");
assert(light_baffle >= 1.2,
       "light chamber needs at least a 1.2 mm opaque baffle");
assert(light_chamber_depth > 0,
       "light chamber must remain behind its LED entry");
assert(light_chamber_rear_height - light_chamber_front_height
       <= light_chamber_depth + 0.001,
       "light chamber roof must be no steeper than 45 degrees");
assert(light_chamber_floor_z + light_chamber_rear_height <= exterior[2] - wall,
       "light chamber must not break through the shell roof");
assert(light_window_width > 0 && light_window_height > 0,
       "light window must leave a positive framed opening");
assert((light_chamber_width - light_window_width) / 2 + 0.001 >= light_baffle,
       "light window must retain its side baffles");
assert(light_window_bottom_z >= steam_center_z - steam_flange[1] / 2 + light_baffle
       && light_window_bottom_z + light_window_height
          <= steam_center_z + steam_flange[1] / 2 - light_baffle,
       "light window must retain top and bottom insert baffles");
assert(light_window_y <= insert_rear_y
       && light_window_y + light_window_depth >= light_chamber_rear_y,
       "light window must connect the insert rear face to the chamber");
assert(steam_seal_depth > 0 && steam_seal_height > 0,
       "steam-track base seal must have positive dimensions");
assert(steam_seal_y >= steam_track_y
       && steam_seal_y + steam_seal_depth <= insert_rear_y,
       "steam-track base seal must remain inside the loading track");
assert(part == "shell" || part == "base" || part == "steam" || part == "coupon",
       str("unknown part: ", part));

module rounded_rect(size, radius) {
    offset(r = radius)
        square([size[0] - 2 * radius, size[1] - 2 * radius], center = true);
}

// A rectangular cable opening with a 45-degree self-supporting roof.
module house_2d(size) {
    width = size[0];
    height = size[1];
    polygon([
        [-width / 2, -height / 2],
        [ width / 2, -height / 2],
        [ width / 2,  height / 2 - width / 2],
        [0, height / 2],
        [-width / 2,  height / 2 - width / 2]
    ]);
}

module link_blobs(a, b, radius = 1.8) {
    hull() {
        translate(a) circle(r = radius);
        translate(b) circle(r = radius);
    }
}

// Three wisps share the rounded lower bar, making one printable body.
module steam_2d(clearance = 0) {
    offset(delta = clearance)
        union() {
            translate([0, -7.2]) rounded_rect([31, 3.2], 1.6);

            link_blobs([-10, -6.5], [-12, -2.5]);
            link_blobs([-12, -2.5], [-9, 2]);
            link_blobs([-9, 2], [-11, 7]);

            link_blobs([0, -6.5], [-2, -1.5]);
            link_blobs([-2, -1.5], [2, 3]);
            link_blobs([2, 3], [0, 9]);

            link_blobs([10, -6.5], [8, -2.5]);
            link_blobs([8, -2.5], [11, 2]);
            link_blobs([11, 2], [9, 7]);
        }
}

module rocker_cut(height = wall + 2 * eps) {
    linear_extrude(height = height)
        rounded_rect(rocker_open, rocker_corner_radius);
}

module usb_cut(depth = 22) {
    // Local Y becomes global Z; extrusion travels toward the enclosure interior.
    translate([0, exterior[1] / 2 + eps, usb_center_z])
        rotate([90, 0, 0])
            linear_extrude(height = depth)
                house_2d([usb[0] + 2 * fit, usb[1] + 2 * fit]);
}

module steam_cut() {
    translate([0, -exterior[1] / 2 + wall + 0.5, steam_center_z])
        rotate([90, 0, 0])
            linear_extrude(height = wall + 1)
                steam_2d(fit);
}

// The tapered cavity creates a hidden roof no steeper than 45 degrees.
module shell_skin() {
    difference() {
        linear_extrude(height = exterior[2])
            rounded_rect([exterior[0], exterior[1]], outer_radius);

        // The lower taper is 45 degrees even at its corners and remains wider
        // than the board through the board/clip height.
        translate([0, 0, -eps])
            linear_extrude(
                height = lower_roof_height + 2 * eps,
                scale = [roof_support[0] / inner[0],
                         roof_support[1] / inner[1]]
            )
                rounded_rect(inner, outer_radius - wall);

        translate([0, 0, roof_start_z - eps])
            linear_extrude(
                height = exterior[2] - wall - roof_start_z + 2 * eps,
                scale = [rocker_open[0] / roof_support[0],
                         rocker_open[1] / roof_support[1]]
            )
                scale([roof_support[0] / inner[0],
                       roof_support[1] / inner[1]])
                    rounded_rect(inner, outer_radius - wall);

        translate([0, 0, exterior[2] - wall - eps])
            rocker_cut(wall + 2 * eps);
        usb_cut();
        steam_cut();

        // A base-loaded track traps the translucent flange behind the face.
        insert_track();

        // Enclosed light chamber with a 45-degree rear-to-front roof.
        light_chamber();

        // A framed aperture carries light onto the insert's rear face while
        // preserving opaque baffles on every edge of the chamber.
        light_window();

        // A self-supporting 5 mm LED entry from the main cavity.
        translate([0, light_chamber_front_y - eps, light_entry_center_z])
            rotate([-90, 0, 0])
                linear_extrude(height = 10)
                    house_2d(light_entry_size);
    }
}

module light_chamber() {
    hull() {
        translate([-light_chamber_width / 2, light_chamber_front_y,
                   light_chamber_floor_z])
            cube([light_chamber_width, eps, light_chamber_front_height]);
        translate([-light_chamber_width / 2, light_chamber_rear_y,
                   light_chamber_floor_z])
            cube([light_chamber_width, eps, light_chamber_rear_height]);
    }
}

module light_window() {
    translate([-light_window_width / 2, light_window_y,
               light_window_bottom_z])
        cube([light_window_width, light_window_depth, light_window_height]);
}

module insert_track() {
    // The 45-degree ridge avoids a flat ceiling over the long loading slot.
    hull() {
        translate([-steam_track_width / 2, steam_track_y, -eps])
            cube([steam_track_width, steam_track_depth, steam_track_top + eps]);
        translate([
            -steam_track_width / 2,
            steam_track_y + steam_track_roof_run - eps / 2,
            steam_track_top + steam_track_roof_rise
        ])
            cube([steam_track_width, eps, eps]);
    }
}

// Three clips on each side form two segmented PCB edge rails. They rise from
// the base, flex independently, and avoid relying on unknown mounting holes.
module board_rail(right = true) {
    rail_inner = board[0] / 2 + fit;
    rail_outer = rail_inner + 1.8;
    wedge = 0.9;
    clip_length = 9;

    points_right = [
        [rail_inner, base_thickness - eps],
        [rail_outer, base_thickness - eps],
        [rail_outer, board_top_z + 2 * wedge],
        [rail_inner, board_top_z + 2 * wedge],
        [rail_inner - wedge, board_top_z + wedge],
        [rail_inner, board_top_z]
    ];
    points_left = [for (p = points_right) [-p[0], p[1]]];

    for (y = [-17, 0, 17])
        translate([0, y + clip_length / 2, 0])
            rotate([90, 0, 0])
                linear_extrude(height = clip_length)
                    polygon(right ? points_right : points_left);
}

module bosses() {
    for (x = [-boss_center[0], boss_center[0]])
        for (y = [-boss_center[1], boss_center[1]]) {
            boss_ramp(x, y);
            boss_upright(x, y);
        }
}

// The ramp has no horizontal lower face after the pilot is cut.  Its furthest
// edge reaches the wall braces over boss_ramp_height, which is at least its
// radial run, so it prints without support from the open bottom.
module boss_ramp(x, y) {
    hull() {
        translate([x, y, boss_bottom_z])
            cylinder(d = m2_pilot, h = eps);
        translate([x, y, boss_bottom_z + boss_ramp_height])
            cylinder(d = boss_diameter, h = eps);
        translate([sign(x) * (inner[0] / 2 + wall / 2), y,
                   boss_bottom_z + boss_ramp_height])
            cylinder(d = boss_brace_diameter, h = eps);
    }
    hull() {
        translate([x, y, boss_bottom_z])
            cylinder(d = m2_pilot, h = eps);
        translate([x, y, boss_bottom_z + boss_ramp_height])
            cylinder(d = boss_diameter, h = eps);
        translate([x, sign(y) * (inner[1] / 2 + wall / 2),
                   boss_bottom_z + boss_ramp_height])
            cylinder(d = boss_brace_diameter, h = eps);
    }
}

// Vertical material starts only after the self-supporting lower ramp.
module boss_upright(x, y) {
    translate([x, y, boss_bottom_z + boss_ramp_height])
        cylinder(d = boss_diameter, h = boss_straight_height);
    hull() {
        translate([x, y, boss_bottom_z + boss_ramp_height])
            cylinder(d = boss_diameter, h = boss_straight_height);
        translate([sign(x) * (inner[0] / 2 + wall / 2), y,
                   boss_bottom_z + boss_ramp_height])
            cylinder(d = boss_brace_diameter, h = boss_straight_height);
    }
    hull() {
        translate([x, y, boss_bottom_z + boss_ramp_height])
            cylinder(d = boss_diameter, h = boss_straight_height);
        translate([x, sign(y) * (inner[1] / 2 + wall / 2),
                   boss_bottom_z + boss_ramp_height])
            cylinder(d = boss_brace_diameter, h = boss_straight_height);
    }
}

module boss_pilots() {
    for (x = [-boss_center[0], boss_center[0]])
        for (y = [-boss_center[1], boss_center[1]])
            translate([x, y, boss_bottom_z - eps])
                cylinder(d = m2_pilot, h = boss_height + 2 * eps);
}

module shell() {
    difference() {
        union() {
            shell_skin();
            bosses();
        }
        boss_pilots();
    }
}

module rounded_slot(size) {
    rounded_rect(size, min(size[0], size[1]) / 2);
}

module board_retaining_pads() {
    pad_height = board_bottom_z - base_thickness - 0.10;
    for (x = [-board[0] / 2 + 2, board[0] / 2 - 2])
        for (y = [-board[1] / 2 + 6, board[1] / 2 - 6])
            translate([x - 1.5, y - 2.5, base_thickness - eps])
                cube([3, 5, pad_height + eps]);
}

module base() {
    union() {
        difference() {
            linear_extrude(height = base_thickness)
                rounded_rect(base_size, base_radius);

            for (x = [-boss_center[0], boss_center[0]])
                for (y = [-boss_center[1], boss_center[1]])
                    translate([x, y, -eps])
                        cylinder(d = m2_clearance, h = base_thickness + 2 * eps);

            for (x = [-18, -6, 6, 18])
                translate([x, 0, -eps])
                    linear_extrude(height = base_thickness + 2 * eps)
                        rounded_slot([3.2, 17]);
        }

        board_retaining_pads();
        board_rail(false);
        board_rail(true);

        // Closes the steam-insert loading track when the base is installed.
        translate([-steam_seal_width / 2, steam_seal_y, base_thickness - eps])
            cube([steam_seal_width, steam_seal_depth, steam_seal_height + eps]);
    }
}

module steam_insert() {
    // Print flange-down. The raised wisps face inward toward the LED chamber.
    linear_extrude(height = flange_thickness)
        rounded_rect(steam_flange, 2);
    translate([0, 0, flange_thickness - eps])
        linear_extrude(height = insert_thickness + eps)
            steam_2d();
}

module fit_coupon() {
    coupon = [52, 28];
    difference() {
        linear_extrude(height = 3)
            rounded_rect(coupon, 3);

        translate([-14, 0, -eps])
            rocker_cut(3 + 2 * eps);

        translate([13, 0, -eps])
            linear_extrude(height = 3 + 2 * eps)
                house_2d([usb[0] + 2 * fit, usb[1] + 2 * fit]);
    }
}

if (part == "shell") shell();
if (part == "base") base();
if (part == "steam") steam_insert();
if (part == "coupon") fit_coupon();
