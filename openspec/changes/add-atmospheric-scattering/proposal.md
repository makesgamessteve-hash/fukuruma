# Proposal

## Why

Skies, sunsets and the glowing limb of a world seen from orbit should follow from each world's air (CONCEPT §4.4:
"blue, orange, green or violet skies and sunsets that follow from the planet's data, the same model seen from orbit
and from the ground"), not from a flat background colour.

## What Changes

- `atmosphere.glsl`: a full-screen pass after lighting and particles: single scattering of the star's light along each
  view ray through the air (Rayleigh, Mie with a Henyey-Greenstein phase, an ozone-like absorbing layer), with 16
  samples spaced densely near the eye and 4 towards the star, the world's shadow, and aerial perspective over the scene.
  Where a ray meets the world beyond what is drawn, it sees the surface's lit colour. WebGL 2 compatible.
- `fk.gfx.atmosphere{centre, radius, top, height, rayleigh, mie, absorb, ground}` per frame; planets from orbit set
  theirs (scaled consistently in scaled space); the range sets its world's air, so its sky, horizon and sunsets now
  come from the scattering (the background is black space).

## Capabilities

### New Capabilities
- `atmospheric-scattering`: the air seen from the ground and from space.

## Impact

`data/shaders/atmosphere.glsl`, `engine/src/gfx/{frame.h,frame.c,gl_pipeline.c}`, `engine/src/script/lua_gfx.c`,
`data/scripts/{planet_view,universe,main}.lua`; sandbox and planet goldens change on purpose.
