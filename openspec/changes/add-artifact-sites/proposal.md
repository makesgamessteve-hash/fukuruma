# Proposal

## Why

Plan M11 asks for ruins with puzzles and defences, the concept's "biggest rewards and strangest deaths".

## What Changes

- Each world has a ruin from the seed: broken pillars and three pylons. It is an exotic sensor signature, which the
  Jump Ship and the Exosuit can sense.
- The puzzle: the pylons must be woken (F) in an order the ruin hints at. Each pylon shows as many glyphs as its place
  in the order, and a native can tell the rule.
- The right order yields the artifact, which goes into the codex's finds.
- A wrong pylon resets the puzzle and wakes the guardian. For 12 seconds it pulses at a suit within 40 m every 2
  seconds.
- Presentation: lit glyphs, the guardian's red eye, and feedback bundles with ship AI lines.

## Capabilities

### New Capabilities
- `artifact-sites`: ruins, their puzzle, their guardian and their artifact.

## Impact

New: `data/scripts/artifacts.lua`. Changed: `survival.lua` (artifacts in the codex), `main.lua`, `feedback.lua` and
`ship_ai.lua`. Covered by `tests/lua/civilisations_test.lua` and the `civilisations` scenario.
