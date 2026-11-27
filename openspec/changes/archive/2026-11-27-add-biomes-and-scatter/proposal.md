# Proposal

## Why

The ground should carry life and stones where its world allows them (CONCEPT §4.5; plan M5: "biome scatter
(instanced detailed flora and rocks with wind animation and impostors)").

## What Changes

- Renderer: instances (`fk.gfx.instances`, the `instances` draw option): one mesh drawn many times in one call, each
  placed, scaled, turned and tinted; the vertex stages (G-buffer and shadows) bend instances in the wind
  (`fk.gfx.wind{direction, strength, time}`), more the higher a point is, with gusts.
- `scatter.lua`: the biome of each 2 m cell of a 128 m grid around the eye from the ground's own colour and slope
  (`planet:grid` can now return colours): grass, shrubs and conifers on green ground, rocks on steep, dry and frozen
  ground; a hash of each cell places them, so the same place always looks the same; nothing on the deck. Beyond it, a
  512 m grid of far trees drawn as single cones stands in for the full ones (the plan's impostors as low-poly stand-ins).
  Procedural meshes; presentation only.
- Graphics levels gain "Plants" (0.3, 0.6, 1 or 1.5 of the plants).

## Capabilities

### New Capabilities
- `biomes-and-scatter`: flora and rocks over the ground, swaying in the wind.

## Impact

`engine/src/gfx/{gfx.h,gl.h,gl_gfx.c,gl_pipeline.c,frame.h,frame.c}`, `engine/src/script/{lua_gfx,lua_planet}.c`,
`engine/src/gen/planet.{c,h}`, `data/shaders/{common,gbuffer,shadow}.glsl`, `data/scripts/{scatter,main,menu}.lua`,
`data/scripts/settings/graphics.lua`; new `tests/game/scatter.lua`; menu goldens change on purpose.
