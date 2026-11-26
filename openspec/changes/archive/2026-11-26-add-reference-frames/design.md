# Design

## Frames in Lua doubles

Lua numbers are doubles, and the frame tree is small (systems, bodies, vessels): Lua keeps it simple, saveable
(frames are plain components) and deterministic (only arithmetic and sqrt). Hot loops over many objects can move
to C later without changing the model. A frame's transform to its parent is `x' = R(q) x + p`; velocities add the
frame's velocity and `w × (R x)`. Conversions walk up from the source to the nearest common ancestor and down to the
target, so two things in the same frame never touch the large offsets above them: a cube next to a camera in a
station frame at 100 AU is exact, where the same cube seen from the system frame would be off by up to ~2 mm.

## Depth slices with depth ranges, not clears

Clearing depth between slices would leave only the last slice's depth, and the deferred passes rebuild positions
from depth. Instead each slice draws with `glDepthRange(lo, hi)` into its own part of the one depth buffer:
near [0, 0.03), local [0.03, 0.75), planetary [0.75, 0.9), celestial [0.9, 0.9999); above that is the sky. A nearer
slice's range is lower, so it always wins the depth test, and the G-buffer, lighting and post passes stay single
passes. `view_position(uv, depth)` in `common.glsl` finds the slice from the depth, maps the depth back to 0..1
and uses that slice's inverse projection (with the frame's TAA jitter). Reprojection for TAA only needs x and y,
which do not depend on the near and far planes. Shadow cascades cover the near and local slices; farther slices
are outside the cascades and lit unshadowed. Ambient occlusion skips planetary and celestial pixels. Particles are
in the local slice. All of it works on WebGL 2 (no `glClipControl`, no logarithmic depth).

## Scaled space

`frames.place_in_slices(rel, r)`: within the local far plane: local; ending within the planetary far plane (2e7 m):
planetary, at its true position; otherwise celestial, at `SCALED_DISTANCE` (1e8 m) with the scale
`SCALED_DISTANCE / d`, which keeps the angular size.
