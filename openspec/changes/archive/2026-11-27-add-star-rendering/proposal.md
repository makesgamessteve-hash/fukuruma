# Proposal

## Why

Stars and neighbouring worlds should look like what they are (CONCEPT §4.4): stars as glowing, boiling discs of their
own colour, pulsars with sweeping beams, binaries lighting worlds with two coloured lights, and nearby planets as real
surfaces in the sky rather than dots.

## What Changes

- `star_view.lua`: a star is an HDR emissive sphere whose vertex colours carry convection cells and spots (noise graphs)
  and tint its emission (`emissive_colors` draw option); bloom and eye adaptation make the glow. A pulsar adds a beam
  sweeping round with its period.
- `fk.gfx.sun2{direction, color, intensity}`: a second, unshadowed directional light for a binary's other star.
- `universe.draw_sky` draws stars with `star_view` and neighbours that span more than a few pixels with `planet_view`
  (tilted and turning with their day); smaller ones stay simple spheres.

## Capabilities

### New Capabilities
- `star-rendering`: stars, pulsars, binary light and neighbouring worlds in the sky.

## Impact

`data/scripts/{star_view,universe,main}.lua`, `data/shaders/{gbuffer,lighting}.glsl`,
`engine/src/gfx/{frame.h,frame.c,gl_pipeline.c}`, `engine/src/script/lua_gfx.c`; new `tests/game/stars.lua` goldens.
