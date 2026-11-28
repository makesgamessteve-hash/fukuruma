# Proposal

## Why

The owner: the Drop Ship carries the Continental Explorer down to the planet, so a 100 m Drop Ship next to a 6.7 km
Continental Explorer looks absurd. The Drop Ship has to be big enough to contain the Continental Explorer.

## What Changes

- **Size and hold.** The Drop Ship is 12 km: its ball is about 7 km across, around a Continental Explorer of 6.7 km. It
  carries one Continental Explorer.
  - It flies like a carrier: slower turns, and at least 4 km above the ground.
  - It deploys 16 km beside the doll it comes out of.
- **The Continental Explorer no longer carries a Drop Ship.**
- **The waiting Drop Ship.** At the start, the Drop Ship that brought the Continental Explorer down waits beside it, its
  hold empty: its parent is the station, and the station's hold counts it as out. This is the way up from the
  Continental Explorer to the station, as before.
- **Taking a Continental Explorer aboard.** From a Drop Ship's seat, the recall command also takes in a Continental
  Explorer near it, whoever deployed it, as long as nothing of it is out. Deploying from the Drop Ship sets it down
  again.
- **A crash fixed.** Hangar lights for hangars this big were brighter than the engine allows, and stopped the game in
  the Jump Ship's Drop Ship hangar.
- **Concept.** The concept's Drop Ship entry is updated.

## Capabilities

### Modified Capabilities
- `doll-chain`: the Drop Ship carries a Continental Explorer.

## Impact

- Changed: `dolls/drop_ship.lua`, `dolls/continental_explorer.lua`, `chain.lua`, `main.lua` and `docs/CONCEPT.md`.
- The travel, fukuruma, chain and hangars tests board the waiting Drop Ship instead of deploying one from the
  Continental Explorer. `chain_test` checks the carrying.
- Goldens and hashes change on purpose.
