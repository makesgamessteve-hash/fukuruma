# Proposal

## Why

Each generated body needs to become a world one can look at (CONCEPT §4.2 "Each class is a Lua archetype with ...
a noise-graph recipe, material and colour-grading rules"): its relief, oceans, colours, air, clouds and grading,
from its class and seed, the same every time.

## What Changes

- `gen/planets.lua`: a recipe registry per planet class (continents with warped fBm and masked ridges; mesas and dunes;
  lava rifts from cell edges with lava seas; ice with cracks; cratered worlds; banded giants), each with relief, sea
  level, ocean, life and a palette; `planets.describe(body)` builds the descriptor: an `fk.planet` surface (height,
  moisture and cloud graphs), air optics per gas (Rayleigh, Mie and absorption per metre at the surface, scale height,
  top), and colour grading.
- Fields per point in C (`gen/planet.c`): elevation over sea level, temperature by latitude and height, moisture,
  biomes (grass, forest, desert, tundra) on living worlds, beaches, frozen seas, peaks and polar ice; cloud layers
  painted from far away and fading out with detail.

## Capabilities

### New Capabilities
- `planet-descriptors`: recipes, fields, air optics, clouds, grading.

## Impact

`data/scripts/gen/planets.lua`, `engine/src/gen/planet.{c,h}`, `engine/src/script/lua_planet.c`; tests `planets_test.lua`.
