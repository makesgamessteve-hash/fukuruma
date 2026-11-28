# Proposal

## Why

The chain spans the ground, the sky and orbit (CONCEPT §2.4). The Commander teleports between the Jump Ship and the
stations, and a Drop Ship goes between orbit and the dolls below. Autopilot lets a doll travel by itself. After
`add-vehicle-controllers` the Commander could climb straight from the Continental Explorer into orbit, and nothing
travelled unattended.

## What Changes

- **Boarding rules:**
  - Between orbit and the ground (or sky) only a Drop Ship goes.
  - A Drop Ship docks with any doll near it, in either direction.
  - Dolls in orbit reach each other's hangars.
- **Teleport network:** `teleport {id}` takes the Commander between the Jump Ship and any station, however far apart.
- **Autopilot:** `autopilot {id}` sends the doll the Commander sits in to another doll. It steers towards the target
  using only deterministic arithmetic, with no angles. It flies up or down to the target's height, arrives within half
  its reach, and announces the arrival. A doll on autopilot keeps going after the Commander has left, and any steering
  by hand cancels it.
- **Speed with height:** flying dolls go faster and climb faster the higher they are, up to 8 km/s, so a Drop Ship
  crosses the 400 km between the ground and the station in about three minutes.
- **Controls:**
  - P: teleport.
  - O: autopilot.

  The autopilot's target is chosen for you: a Drop Ship low down heads for the nearest doll in orbit, and high up for
  the nearest Continental Explorer. Any other doll goes back to its parent.
- **Screens and feedback:** the screens show the autopilot's target and the teleport node. Teleporting, engaging the
  autopilot and arriving each have feedback bundles.
- **Shortcut:** the Jump Ship parks 1,200 km up, not in a truly high orbit, until dolls are drawn relative to the
  camera. Further out, 32-bit positions break its bridge.

## Capabilities

### New Capabilities
- `travel`: the teleport network, the Drop Ship's role and autopilot.

## Impact

Changed: `data/scripts/{chain,main,feedback}.lua` and `data/scripts/dolls/{jump_ship,drop_ship}.lua`. New:
`tests/game/travel.lua` with three goldens. `tests/lua/chain_test.lua` is extended. Hashes are re-recorded on purpose.
