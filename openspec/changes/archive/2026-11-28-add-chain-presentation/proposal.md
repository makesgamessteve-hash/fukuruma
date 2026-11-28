# Proposal

## Why

The plan's M6 asks for the orientation view per doll, ship-AI text lines, and deploys watched as they happen. Until
now, the survey drone always circled the suit, nothing spoke, and deployed dolls popped into place.

## What Changes

- At a doll's controls, the survey drone (V) circles that doll at a distance scaled to its size.
- `ship_ai.lua`: the ship AI says what the chain does in a line at the bottom of the view, for a few seconds. It
  covers deploys, recalls, boarding, teleports, the autopilot engaging and arriving. Presentation only.
- A newly deployed doll eases out of its parent over three seconds. This is presentation only: the simulation places
  it at once.
- Fix: dolls more than 400 m away are drawn in the planetary depth slice. The local slice ends at 400 m, which hid
  them before.

## Capabilities

### Modified Capabilities
- `doll-chain`: the orientation view per doll, the ship AI's lines, the deploy easing.

## Impact

New: `data/scripts/ship_ai.lua`, `tests/lua/ship_ai_test.lua`, and `tests/game/chain_views.lua` with three goldens.
Changed: `data/scripts/{chain,main}.lua`. The chain, travel and Fukuruma goldens change on purpose, because distant
dolls now show.
