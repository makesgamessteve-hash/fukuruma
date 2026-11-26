# Proposal

## Why

M2 makes the game precise from a 1 cm spore to a 144 km Jump Ship in a system 100 AU across (plan §3.3). Floats
alone cannot hold positions that far from the origin, and one depth buffer cannot hold a cockpit, a hull and a
planet at once. Everything after M2 (systems, planets, surfaces, the Fukuruma chain) stands on this.

## What Changes

- **Frame tree** (`fk/frames.lua`): frames as simulation state (the `frame` component): a parent, a position,
  a velocity, a rotation and a spin, in doubles. Points, velocities and orientations convert between any two
  frames through their nearest common ancestor, so things in the same far frame keep full precision.
- **Frame transitions:** an entity's `place` moves into another frame, keeping its world position, velocity and
  orientation.
- **Camera-relative drawing:** a viewer turns a thing in any frame into a matrix relative to the camera, computed
  in doubles, so nothing jitters far from the origin.
- **Depth slices** (renderer): near (cockpits and hands), local, planetary and celestial. Each slice has its own
  near and far planes and writes its own part of the one depth buffer (`glDepthRange`), so a nearer slice is
  always in front; the deferred passes (lighting, ambient occlusion, TAA, particles) find a pixel's slice from its
  depth and use that slice's projection. `fk.gfx.draw(..., {slice = ...})`, `fk.gfx.slices{...}`.
- **Scaled space:** things beyond the planetary slice are drawn moved closer and shrunk by the same factor, keeping
  their angular size.
- **Scale ladder:** a scene and game test: a 1 m cube, a 144 km hull, an Earth-sized planet and a Sun-like star in
  one frame tree, a golden image at each step, and position jitter below 1 mm at 100 AU.
- **Fix:** the BRDF could return NaN when rounding pushed `dot(v, h)` above 1 (bloom then spread it into a black
  block); the terms are clamped.

## Capabilities

### New Capabilities
- `reference-frames`: frame tree, precision, transitions, camera-relative drawing, scaled space.

### Modified Capabilities
- `rendering`: depth slices.

## Impact

`data/scripts/fk/frames.lua`, `data/scripts/scale_ladder.lua` (new); `engine/src/gfx/{frame.h,frame.c,
gl_pipeline.c,gl.h,gl_gfx.c}`, `engine/src/script/lua_gfx.c`; `data/shaders/{common,lighting,ssao,taa,particle}.glsl`;
tests `frames_test.lua`, `scale_ladder_test.lua`, `gfx_test.lua`, `tests/game/scale_ladder.lua` with four goldens.
Existing goldens are unchanged.
