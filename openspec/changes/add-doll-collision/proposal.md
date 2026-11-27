# Proposal

## Why

The Walker's and the Land Explorer's legs were only drawn: the suit and the crates walked through them (plan M6:
"dolls that feel their mass").

## What Changes

- Each leg of a doll standing on the ground gets a kinematic column in the physics world, from its foot up to its
  knee. `hull.feet` gives where the legs stand, so the columns match the drawn legs.
- The columns are made when the doll is out, move and turn with it every tick, and are removed when it is recalled.
  Their IDs are part of the doll's saved state.
- The Exosuit isn't covered: it is the suit's own physics body.

## Capabilities

### Modified Capabilities
- `doll-chain`: the dolls on the ground are solid where their legs stand.

## Impact

Changed: `data/scripts/{chain,main}.lua` and `data/scripts/dolls/hull.lua`. `tests/lua/chain_test.lua` is extended.
The recorded hashes change on purpose, because the columns are part of the physics state.
