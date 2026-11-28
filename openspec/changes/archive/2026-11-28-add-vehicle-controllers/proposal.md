# Proposal

## Why

Every doll is steered by the Commander from its seat (CONCEPT §2.4, §2.6; plan M6). After `add-doll-chain` and
`add-cockpits` the Commander could sit at every doll's controls, but nothing moved.

## What Changes

- A `drive {throttle, turn, lift}` command steers the doll the Commander sits in. Values are clamped to -1..1. The
  move keys steer, and Space and C lift. The Exosuit keeps walking with the move command, and a doll left behind stops.
- Each doll's definition names its controller:
  - **legged** (Walker, Land Explorer): walks on the ground, turns, speeds up and slows down by its own rates. A
    `stomp` event comes every stride, with a feedback bundle: dust, a jolt, rumble and a boom, scaled by the doll's
    size. The seat bobs with the stride, scaled by the head-bob comfort setting.
  - **flight** (Continental Explorer, Drop Ship): flies, climbs and turns, and stays at least its floor height above
    the ground.
  - **fixed** (Space Station, Jump Ship): holds its place. Their orbits and the jump drive come with the teleport
    network and autopilot.
- Dolls have a heading. Their hulls, cabins, screens and seats turn with it, and the seat's look limit is measured
  from it.

## Capabilities

### New Capabilities
- `vehicle-controllers`: steering each doll from its seat.

## Impact

Changed: `data/scripts/{chain,main,feedback,dolls}.lua`, `data/scripts/dolls/*.lua` (controller fields) and
`data/scripts/dolls/cockpit.lua`. New: `tests/game/drive.lua` with two goldens. `tests/lua/chain_test.lua` is extended.
