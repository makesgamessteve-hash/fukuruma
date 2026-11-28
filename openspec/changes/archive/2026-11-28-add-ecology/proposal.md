# Proposal

## Why

Plan M10 asks for procedural fauna, ecology tables, behaviours at low tick rates and defensive tools. Concept §5.3
puts survival first: avoid, escape, deter. This change covers the plan's `add-ecology`, `add-creature-generation`,
`add-procedural-animation` and `add-defensive-tools`.

## What Changes

- **Creatures.** Each world's species come from its seed through a body-plan grammar: 2, 4 or 6 legs, body, neck,
  head, tail, colours, size, gait speed and stride, and a name from syllables. There is one grazer species and one
  predator species per world. Three herds of five grazers and two packs of three predators live around the range.
  They are sensor hazards, so the dolls see them as bio signatures.
- **Behaviours** run every 6 ticks:
  - grazers wander about their herd and flee predators;
  - predators roam about their den;
  - a predator notices the suit within 22 m at a walk (passive stealth), 70 m at a run and 320 m after hearing a ping,
    then hunts it and bites at arm's length;
  - a predator stops hunting once the Commander is inside a doll.
- **Defensive tools.**
  - Flares (C, the left stick, a touch button), thrown from the suit or fired from a seat, are decoys: for 20 seconds
    they draw predators within 160 m, and they can light dry vegetation.
  - The suit's stun (Q, the left shoulder, a touch button) knocks down what is within 15 m ahead for 6 seconds. It
    has a 5-second cooldown.
- **Procedural animation** (presentation). The body bobs with the steps. The legs swing in pairs from the distance
  walked, and a stunned creature keels over. The decoys burn with a flickering light.
- Every new action and event has its feedback bundle: flare, stun, noticed, bite.

## Capabilities

### New Capabilities
- `ecology`: species, herds and packs, behaviours, stealth, decoys and the stun.

## Impact

- New: `data/scripts/ecology.lua`.
- Changed: `sensors.lua` (a world hook for creatures; the grazer signature), `main.lua` (actions, touch buttons,
  drawing) and `feedback.lua`.
- Covered by `tests/lua/survival_test.lua` and the survival scenario.
