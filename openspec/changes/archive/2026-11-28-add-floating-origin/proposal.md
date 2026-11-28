# Proposal

## Why

32-bit floats hold about 2 m of precision 30,000 km out, so the Jump Ship's bridge broke there. It had to park
1,200 km up instead of in a truly high orbit (CONCEPT §2.2).

## What Changes

- `fk.gfx.origin(x, y, z)`: the frame's floating origin. Every world position that enters the renderer has it
  subtracted in double precision before it becomes a float:
  - model matrices;
  - lights;
  - particles;
  - water and the air;
  - plant instances;
  - digs.

  The camera adds it back, so the combined transform is unchanged, for every depth slice including scaled space.
- When the origin moves, live particles move with it.
- The game sets the origin each frame near the eye, on a 4 km grid, once the eye is more than 16 km from the range.
  Near the range it stays at zero, and the pictures are unchanged.
- The Jump Ship parks 30,000 km up again.

## Capabilities

### Modified Capabilities
- `rendering`: precise geometry far from the draw axes' origin.

## Impact

Changed: `engine/src/script/lua_gfx.c`, `engine/src/fx/particles.{c,h}`, `data/scripts/{main,chain}.lua` and
`data/scripts/dolls/jump_ship.lua`. New tests in `tests/unit/test_fx.c` and `tests/lua/cockpit_test.lua`. The Jump
Ship's goldens and the recorded hashes change on purpose.
