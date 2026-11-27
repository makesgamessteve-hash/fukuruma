# Proposal

## Why

Physics makes systems plausible; the Wonder Director makes them memorable (CONCEPT §4.3). Players should find
something remarkable in every system and be able to steer towards stranger signatures.

## What Changes

- `gen/wonders.lua`: a registry of marvels, each with a rarity among eligible systems, a prerequisite (the bodies or
  system that can hold it), an effect on the descriptor and a scanner signature strength. 22 marvels: a moon through
  the rings (with shepherd gaps), a polar ring, life on an eyeball world's twilight band, a glass desert, crystal
  forests, a shattered world that keeps its air, a moon on a collision course, a pulsar beam sweeping a world, black
  hole lensing, a dead Dyson swarm, an alien Jump Ship wreck, leviathans, cryovolcanoes, a permanent super-storm, a
  binary sunset, methane lakes, iron rain, a frozen tsunami, a fungal network, a giant canyon, a comet swarm, and a
  faint sensor echo.
- Rolls per marvel from the system's seed; a system that rolled nothing gets a fallback marvel; an interest score; the
  strongest signature (4 or more) shows on the galaxy map as an unusual signature.
- `systems.generate` curates every system.

## Capabilities

### New Capabilities
- `wonder-director`: marvels, guarantee, rarity, signatures.

## Impact

`data/scripts/gen/wonders.lua`, `gen/systems.lua`; tests `wonders_test.lua`, `tests/game/systems.lua` (rarity
statistics; the recorded hash changes on purpose).
