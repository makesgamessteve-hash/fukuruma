# Proposal

## Why

Worlds with air should have real weather in their skies: clouds with depth that the star lights and that cast
shadows, fog lying low over the ground, and shafts of light through broken cloud (CONCEPT §4.4; plan M5: "volumetric
clouds with cloud shadows, the froxel fog volume and light shafts").

## What Changes

- Clouds: a layer of the world's air between two heights, density from three octaves of value noise shaped by the
  cover and by the height in the layer, drifting with the wind. The air pass marches each view ray through the layer
  (16 to 48 samples by graphics level, a jittered start per pixel, thinning beyond 18 km), lighting each sample by
  the star through the cloud above it (forward scattering) and a little sky light, in front of what is drawn.
- Cloud shadows: the lighting pass dims the star's light on the ground by the cloud above.
- Fog: extra haze with its own scale height in the air march; shafts of light: each sample of the air's in-scattering
  is dimmed by the cloud above it. (The plan's froxel volume is folded into the existing per-pixel air march, which
  fits the WebGL 2 baseline without a 3D target.)
- `fk.gfx.atmosphere` takes `clouds = {bottom, top, cover, density, offset, steps}` and `fog = {density, height}`;
  the range's world brings its clouds (planet descriptors now carry their cloud cover); graphics levels gain "Clouds"
  (off, 16, 32, 48 samples).

## Capabilities

### New Capabilities
- `volumetric-clouds-and-fog`: clouds, their shadows, fog and light shafts.

## Impact

`engine/src/gfx/{frame.h,gl_pipeline.c}`, `engine/src/script/lua_gfx.c`, `data/shaders/{common,atmosphere,lighting}.glsl`,
`data/scripts/{universe,menu}.lua`, `data/scripts/gen/planets.lua`, `data/scripts/settings/graphics.lua`; new
`tests/game/clouds.lua`; menu goldens change on purpose.
