# Proposal

## Why

M3 ends with the universe being playable: the sky over the range is real, and the Commander can look at the galaxy
and at the current system and jump to another star (CONCEPT §4.1, §4.4 "Maps", the jump sequence). The plan's game
test jumps through three systems.

## What Changes

- **Star map sky** (`gen/sky.c`, renderer): the night sky seen from a point in the galaxy, baked in the background
  (job system) into an HDR cube map: the real stars within 100 ly at their apparent brightness and colour, over the
  galactic band. `fk.gfx.starfield(...)`, `fk.gfx.sky(map, {strength, rotation})`; the lighting pass shows it where
  nothing is drawn. `fk.gfx.draw` takes a `color`.
- **The universe** (`universe.lua`): the simulation keeps the current star and the world the range stands on (a new
  game starts at the nearest Sun-like star with a terran or ocean world) and handles the `jump` command (within 20
  ly); the physics world's gravity is the world's surface gravity (and is saved now). The presentation lights the
  range with the real star, turning with the world's day (night falls, the stars come out), colours the sky by the
  world's air, and draws the system's other bodies in the sky through scaled space.
- **Maps** (`navmap.lua`): the galaxy map (stars within 30 ly from above, the jump range, unusual signatures, a panel
  with the chosen system) and the system map (orbits on a log scale, bodies where they are, a time scrubber, a panel
  with class, temperature, gravity, air and marvels). M, Y or MAP opens them; Tab switches; ← → choose; Enter jumps.
- **The jump sequence:** streaks, a white flash that hides the arrival, a long shake and rumble, and a jump sound
  generated with ElevenLabs.

## Capabilities

### New Capabilities
- `navigation-maps`: the universe state, the maps, the jump.

### Modified Capabilities
- `rendering`: the star map sky.
- `physics`: world gravity is settable and saved.

## Impact

`engine/src/gen/sky.{c,h}`, `engine/src/gfx/{frame,gl_pipeline,gl_gfx}.c`, `gfx.h`, `gl.h`, `engine/src/script/
{lua_gfx,lua_physics}.c`, `engine/src/physics/world.c`; `data/shaders/lighting.glsl`; `data/scripts/{universe,navmap,
main,feedback,touch_view}.lua`, `fk/ui.lua`; `data/sounds/jump.ogg`; tests `navigation_test.lua`, `main_test.lua`,
`tests/game/navigation.lua` with five goldens; the sandbox goldens and hashes change on purpose (the light now comes
from the real star); `tests/reproducible.cmake` runs with the scenario's own seed.
