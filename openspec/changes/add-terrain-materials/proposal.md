# Proposal

## Why

Up close, the ground was flat vertex colour. The concept asks for terrain materials with detail, and wetness, snow and
dust layers that the weather can drive (CONCEPT §4.5; plan M5: "triplanar terrain materials with wetness, snow and
dust layers").

## What Changes

- Planet chunks carry two surface layers per vertex (in the tangent, which chunks do not use): snow cover from the
  temperature (cold heights, polar caps) and wetness at shores (`fk_planet_layers`).
- A terrain material in the G-buffer pass (`terrain` draw option: the chunk's wrapped origin, the world's up, and the
  weather's wetness, snow and dust): solid 3D value noise in four octaves (0.4 m to 25.6 m) that wraps every 256 m with
  the chunk origins, so detail runs on across chunks and needs no projection; each octave fades where a cell is smaller
  than a pixel. Bumps from the detail's own gradient (differences in the chunk's space; screen-space derivatives tipped
  single pixels over at triangle edges), limited to about 19 degrees. Rock on slopes from about 25 degrees; snow on
  the level with a noisy edge; wetness darkens and glosses; dust settles on up-facing ground.
- The material scales with the graphics level ("Ground detail": layers only, with detail, with bumps), so software
  renderers and phones keep their frame rate.
- `planet_view` gives every full-size chunk the material (the detail fades by pixel size, so there is no seam);
  `terrain.draw` takes the weather (rain, snowfall, dust for M5 `add-weather`).

## Capabilities

### New Capabilities
- `terrain-materials`: the ground's look up close and its weather layers.

## Impact

`engine/src/gen/planet.{c,h}`, `engine/src/gfx/{frame.h,gl_pipeline.c}`, `engine/src/script/lua_gfx.c`,
`data/shaders/gbuffer.glsl`, `data/scripts/{planet_view,terrain}.lua`; new `tests/game/terrain_materials.lua`;
descent and sandbox goldens change on purpose.
