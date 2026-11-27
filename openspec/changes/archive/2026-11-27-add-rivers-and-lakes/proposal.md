# Proposal

## Why

Worlds with water should have rivers, lakes and waterfalls on land, not only the sea (CONCEPT §4.5; plan M5:
"oceans, lakes, rivers and waterfalls"). The planet's height is pure noise, with no record of where water runs. So the
water courses are worked out where they are seen up close: in a square around the range.

## What Changes

- New `gen/hydro.c` builds a grid of 256 × 256 cells of 16 m (4 km) around the range, after the site is levelled:
  - the ground's heights get shallow lake basins pressed in, from a smooth noise seeded by the world;
  - the square is flooded from its edges and the sea (priority flood), so basins fill to lakes;
  - every sample drains along the path the flood reached it by, and the flow through each sample is counted;
  - where enough flow passes, a river runs.
- The river channels (with gentler banks) and the basins are carved into `fk_planet_height`. The terrain, its physics
  and the chunks therefore share them. The levelled site stays as it is.
- Water surfaces become a mesh in the range's frame:
  - rivers are ribbons along their courses, wandering a little off the grid, wider with more flow;
  - lakes are flat at their level;
  - the water is white where a river drops steeply or pours into the sea (falls and rapids).

  The mesh is drawn glossy, so it reflects the sky.
- `planet:waters{up, east, north, n, cell, keep}` returns where the biggest river, the highest lake and the highest
  fall are, and which way the water runs there. `planet:water_mesh()` returns the water surfaces.
- Not in this change: rivers seen from orbit (the courses exist only around the range), flowing or animated water, and
  swimming.

## Capabilities

### New Capabilities
- `rivers-and-lakes`: rivers, lakes and falls on the land around the range.

## Impact

New `engine/src/gen/hydro.{c,h}`. Changed: `engine/src/gen/planet.{c,h}`, `engine/src/script/lua_planet.c`,
`data/scripts/{universe,main}.lua`. New tests: `tests/lua/waters_test.lua` and `tests/game/rivers.lua`, with three
goldens.
