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
inner = [exterior[0] - 2 * wall, exterior[1] - 2 * wall];
boss_spacing = [60, 52];
boss_diameter = 7.6;
board_top_z = 9.4;
board_bottom_z = board_top_z - pcb_thickness;
steam_center_z = 28;
steam_flange = [38, 24];
roof_start_z = exterior[2] - wall
               - max((inner[0] - rocker_open[0]) / 2,
                     (inner[1] - rocker_open[1]) / 2);

assert(wall >= 2.4, "wall must be at least 2.4 mm");
assert(exterior[0] > board[0] + 2 * wall);
assert(exterior[1] > board[1] + 2 * wall);
assert(roof_start_z >= board_top_z + 1.8,
       "board clips collide with the tapered roof");
assert((inner[0] - rocker_open[0]) / 2
       <= exterior[2] - wall - roof_start_z + 0.001);
assert((inner[1] - rocker_open[1]) / 2
       <= exterior[2] - wall - roof_start_z + 0.001);
assert(usb[1] + 2 * fit >= (usb[0] + 2 * fit) / 2,
       "USB opening must be tall enough for its 45-degree roof");
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
        rounded_rect(rocker_open, 0.6);
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

        // Preserve full board clearance below the support-free roof.
        translate([0, 0, -eps])
            linear_extrude(height = roof_start_z + 2 * eps)
                rounded_rect(inner, outer_radius - wall);

        translate([0, 0, roof_start_z - eps])
            linear_extrude(
                height = exterior[2] - wall - roof_start_z + 2 * eps,
                scale = [rocker_open[0] / inner[0], rocker_open[1] / inner[1]]
            )
                rounded_rect(inner, outer_radius - wall);

        translate([0, 0, exterior[2] - wall - eps])
            rocker_cut(wall + 2 * eps);
        usb_cut();
        steam_cut();

        // A base-loaded track traps the translucent flange behind the face.
        insert_track();

        // Enclosed light chamber with a 45-degree rear-to-front roof.
        light_chamber();

        // A self-supporting 5 mm LED entry from the main cavity.
        translate([0, -22.5 - eps, 29])
            rotate([-90, 0, 0])
                linear_extrude(height = 10)
                    house_2d([5.4 + 2 * fit, 5.5 + 2 * fit]);
    }
}

module light_chamber() {
    hull() {
        translate([-17.5, -28.9, 25])
            cube([35, 6.4, 7.6]);
        translate([-17.5, -28.9, 25])
            cube([35, eps, 14]);
    }
}

module insert_track() {
    track_width = steam_flange[0] + 2 * fit;
    track_depth = flange_thickness + insert_thickness + 2 * fit;
    track_top = steam_center_z + steam_flange[1] / 2 + fit;
    track_y = -exterior[1] / 2 + 2.05;

    // The 45-degree ridge avoids a flat ceiling over the long loading slot.
    hull() {
        translate([-track_width / 2, track_y, -eps])
            cube([track_width, track_depth, track_top + eps]);
        translate([
            -track_width / 2,
            track_y + track_depth / 2 - eps / 2,
            track_top + track_depth / 2
        ])
            cube([track_width, eps, eps]);
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
    for (x = [-boss_spacing[0] / 2, boss_spacing[0] / 2])
        for (y = [-boss_spacing[1] / 2, boss_spacing[1] / 2])
            translate([x, y, 0]) cylinder(d = boss_diameter, h = 8.5);
}

module boss_pilots() {
    for (x = [-boss_spacing[0] / 2, boss_spacing[0] / 2])
        for (y = [-boss_spacing[1] / 2, boss_spacing[1] / 2])
            translate([x, y, -eps])
                cylinder(d = m2_pilot, h = 8.5 + 2 * eps);
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
    base_size = [
        exterior[0] - 2 * (wall + fit),
        exterior[1] - 2 * (wall + fit)
    ];

    union() {
        difference() {
            linear_extrude(height = base_thickness)
                rounded_rect(base_size, outer_radius - wall - fit);

            for (x = [-boss_spacing[0] / 2, boss_spacing[0] / 2])
                for (y = [-boss_spacing[1] / 2, boss_spacing[1] / 2])
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
        seal_height = steam_center_z - steam_flange[1] / 2
                      - fit - base_thickness;
        translate([-steam_flange[0] / 2, -31.45, base_thickness - eps])
            cube([steam_flange[0], 2.1, seal_height + eps]);
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
