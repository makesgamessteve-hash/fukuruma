# Proposal

## Why

The plan's M6 game test is *the Fukuruma test*: the whole chain down and back up, entirely in first person, run on
every push from now on (plan M6, §4). The doll chain, cockpits, controllers and travel are now in place to run it.

## What Changes

- New `tests/game/fukuruma.lua`, run on every push. It is quick enough to stay out of the slow set.
  - **Up:** from the Exosuit up to the Jump Ship, boarding each doll, taking a Drop Ship on autopilot to the station
    and teleporting.
  - **Down:** by teleport and Drop Ship to the Continental Explorer, then deploying and boarding a fresh Land Explorer,
    Walker and Exosuit, and walking on foot.
  - **Back up:** each new doll recalled into its parent's hold on the way back to the Jump Ship.
  - **Pictures:** two goldens, one on foot and one back on the Jump Ship's bridge.

## Capabilities

### Modified Capabilities
- `doll-chain`: the whole chain can be travelled down and back up in one run.

## Impact

New: `tests/game/fukuruma.lua` and two goldens. Changed: `CMakeLists.txt`.
