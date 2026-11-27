# Proposal

## Why

M6's vertical slice needs the Fukuruma chain itself (CONCEPT §2; plan M6): seven dolls, from the 144 km Jump Ship
down to the 3.6 m Exosuit, plus the Drop Ship. Each doll can deploy the next, recall it and be boarded. This change
lays the chain's foundation. Cockpits, the controllers that steer each doll, the teleport network and autopilot come
in their own changes.

## What Changes

- **Doll registry:** `dolls.register(def)` and one Lua file per doll in `data/scripts/dolls/`. Each definition gives
  the doll's size, what it carries docked, where it stands once deployed (ground, sky or orbit), its offset from the
  doll that deploys it, its seat and its hull. Mods add dolls the same way.
- **Hull grammar:** `dolls/hull.lua` builds a doll's hull from parts in units of its size:
  - lathed shapes;
  - boxes, either of which can be mirrored;
  - splayed legs with feet;
  - seeded greebles.

  Hulls are built once per kind and drawn at the doll's real size, in the depth slice their distance needs.
- **The chain:** a saved simulation component lists the dolls out in the world, where they stand (the range's local
  frame), what each holds docked, and which doll the Commander is in. A new game starts with the whole chain out:
  - the Jump Ship far above;
  - its station in orbit;
  - the Continental Explorer in the sky to the south;
  - the Land Explorer and the Walker on the ground south of the range;
  - the Commander in the Exosuit on the range.
- **Commands:**
  - `deploy {kind}` brings a docked doll out beside the one the Commander is in. A deployed Exosuit is the suit of
    the range.
  - `recall {id}` takes a child back into its hold, if no doll of its own is out.
  - `board {id}` puts the Commander at the controls of a parent or child doll within reach.

  Each command has a feedback bundle (light, shake, rumble, sound). Away from the Exosuit, the suit stands still: it
  doesn't walk, dig or scan. The view is from the doll's seat.
- **Controls:**
  - B: to the parent doll's seat.
  - N: to the nearest child's seat.
  - T: deploy.
  - R: recall.

  Gamepads use the D-pad. Touch layouts come in M7.
- **Shortcuts:**
  - Orbits are parked straight above the range.
  - The chain goes along with a jump; on a new world, its ground dolls stand on the new ground.
  - Dolls other than the Exosuit don't collide yet.
  - Boarding is instant, without the walk between seats.

## Capabilities

### New Capabilities
- `doll-chain`: the dolls, the chain and the deploy, recall and board commands.

## Impact

New: `data/scripts/{dolls,chain}.lua`, `data/scripts/dolls/*.lua`, `tests/lua/chain_test.lua` and
`tests/game/chain.lua` with four goldens. Changed: `data/scripts/{main,dig,feedback}.lua`. The recorded simulation,
physics and navigation hashes change on purpose, because the chain is part of the simulation state.
