# Proposal

## Why

A tunnel stalled after the third dig: the suit stopped at the seam between two digs and could dig no further. Inside a
tunnel, the walls were lit by a blue sky the suit could not see, so tunnels looked blue and flat.

## What Changes

- The physics measures the distance to the solid around the dug space against the real boundary of the dug space:
  - a dig's wall where no other dig covers it;
  - the crease where two digs meet;
  - a dig's rim at the ground.

  It used to take the furthest containing dig's wall. That underestimates the distance where digs overlap, which made
  a ridge at the seam.
- Underground the sky's ambient light fades with the eye's depth. The dug walls also get darker the deeper they lie.
- A warm helmet lamp comes on once the eye is below the ground.
- The dig scenario's tunnel picture looks back up the tunnel to its opening.

## Capabilities

### Modified Capabilities
- `voxel-terrain`: tunnels continue past any number of digs; tunnels are lit by the helmet lamp.

## Impact

`engine/src/physics/terrain.c`, `engine/src/gen/dig.c`, `data/scripts/{dig,main}.lua`, `tests/unit/test_physics.c`,
`tests/lua/dig_test.lua`, `tests/game/dig.lua`. The `dig_pit`, `dig_tunnel` and `dig_after_load` goldens change on purpose.
