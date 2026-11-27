# Proposal

## Why

Worlds with oceans should have water that looks and behaves like water up close: waves, the sky and the star in it,
the floor seen through it, foam at the shore, light rippling on the bottom and murk underneath (CONCEPT §4.5; plan M5:
"oceans, lakes, rivers and waterfalls with waves, reflections, refraction, foam, caustics and underwater fog").

## What Changes

- Oceans have a floor: below sea level the ground keeps its shape (at half its depth) instead of being cut flat at the
  surface; the suit walks on it under the water.
- A water pass (`water.glsl`, full screen, after the lighting): where a view ray meets the sea (a sphere at sea level)
  before anything drawn, the surface: six moving swells for its normals (short waves fade with distance), Fresnel
  reflection of the sky and a glint of the star, the drawn floor refracted and dimmed by the depth of water it is seen
  through (red first), shallow and deep tints, and foam along the shore. From under the surface the scene is seen
  through water. The sea reaches the horizon without a mesh.
- Caustics: the lighting pass dims the star's light on the sea floor with depth and gathers it into moving threads.
- `fk.gfx.water{centre, radius, deep, shallow, time, waves}`; the range's world shows its sea when it has an ocean.
- Not in this change: rivers, waterfalls and lakes above sea level, which need water courses in the world's data
  (they stay on the plan's list for M5).

## Capabilities

### New Capabilities
- `water`: the sea up close, from above and from below.

## Impact

`engine/src/gen/planet.{c,h}`, `engine/src/gfx/{frame.h,frame.c,gl_pipeline.c}`, `engine/src/script/lua_gfx.c`,
`data/shaders/{common,lighting,water}.glsl`, `data/scripts/{main.lua,gen/planets.lua}`; new `tests/game/water.lua`;
goldens of worlds with oceans change on purpose.
