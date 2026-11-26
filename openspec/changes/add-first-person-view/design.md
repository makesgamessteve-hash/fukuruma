# Design

## Looking is presentation, the facing is simulation

The helmet's yaw and pitch live in the presentation (camera rig), like the mouse itself. The simulation only needs
where the suit faces, so the `move` command carries the wanted velocity and the flat look direction
`{x, z, fx, fz}`, quantised to 1/1000 so small mouse jitter does not flood the command stream. The tick turns the
suit's facing towards the look direction. Saves therefore keep the facing, and loading turns the helmet to it.

## Eyes in the head

The eye is the head joint's matrix times a fixed offset behind the visor. Head bob comes for free from the walk and
run clips; the comfort setting blends between that point and the same point with the head at rest. The head node
is scaled to zero before drawing, which hides the helmet shell and the antenna from inside while the shoulders and
arms stay visible. Scaling a node is the smallest engine addition that does this (no per-mesh visibility).

## The drone

An orbit rig around the suit, opened behind the Commander's current look direction. Movement and scanning are off
while it is open: the input sends a zero wish, so the suit stops in the simulation as it would when the stick is
released. Closing it on damage (CONCEPT §2.6) waits until damage exists.

## Mouse capture

`fk.input.capture(on)` sets SDL relative mouse mode (pointer lock in browsers). The sandbox captures while no menu
is open and the last device is not touch. Browsers grant pointer lock only after a click; until then the mouse
moves the cursor and the view does not turn, which is the expected browser behaviour.

## Menu height

Three comfort rows make 21 rows plus the title; at 12 px per row that is 276 px, more than the 270-px image. Rows
are 11 px now (8-px font, 3 px spacing).
