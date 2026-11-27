# Proposal

## Why

Every star in the galaxy is a place (CONCEPT §4.2): its system must be generated from its seed, plausibly enough to
believe and fast enough to do on demand, with orbits that M2's frames and Kepler rails can move.

## What Changes

- `gen/systems.lua`: from a galaxy star to a system descriptor of plain data: stars (binaries on barycentric orbits),
  planets, moons, rings, Trojans, belts, comets and disks, all with Kepler elements in metres. One `fk.rng` stream per
  system; only arithmetic, `math.sqrt`/`floor` and `fk.math` (never Lua's `^` or the C library's functions).
- The eleven system archetypes as a registry (`systems.archetype`): single star, close binary with circumbinary
  planets, wide binary (each star with its planets), hierarchical triple, star with a brown dwarf, white dwarf with a
  debris disk, pulsar with irradiated worlds, black hole with an accretion disk, young star with a protoplanetary
  disk, red giant that swallowed its inner planets, rogue planet with no star.
- Planets spaced by mutual Hill radii (8 to 16, with occasional 3:2 and 2:1 resonance chains) and thinned until every
  neighbour pair is at least 2√3 mutual Hill radii apart from periapsis to apoapsis; masses by place (giants beyond
  the frost line); habitable zone and frost line from luminosity; moons inside half the Hill sphere; rings inside the
  Roche zone and clear of moons.
- Planet classes as a registry (`gen/planet_classes.lua`, 16 classes from lava to shattered) checked in order on mass,
  temperature, water, iron, carbon and tidal locking, each with albedo and atmosphere.
- `gen/checks.lua` checks a descriptor's promises; `tests/game/systems.lua` generates 10,000 systems.

## Capabilities

### New Capabilities
- `star-systems`: archetypes, bodies, orbits, classes, checks.

## Impact

`data/scripts/gen/{units,systems,planet_classes,checks}.lua`; tests `systems_test.lua`, `tests/game/systems.lua`.
