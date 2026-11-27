# Proposal

## Why

The range should stand on its world's real ground, and that ground should run on, without holes, from orbit down to
the suit's feet (CONCEPT §4.5; plan M5: "quadtree chunk streaming from orbit to the ground without cracks; terrain
collision").

## What Changes

- Physics: a terrain heightfield in each world (`fk_world_terrain`, `world:terrain`, `world:height`): bodies and
  characters collide with it (the plane of the triangle under each point: sphere centres, capsule ends, box corners);
  it is not part of the saved state but rebuilt from the world's data.
- Planets: `planet:flatten` levels the range's site; `planet:grid` samples heights in the range's local frame,
  following the curvature. Chunks are centred on the surface (tight bounds); skirts are half a quad deep.
- `terrain.lua`: a 96 m tile of the real surface follows the suit in 16 m steps inside the simulation (a pure function
  of the world and the suit's position, so a loaded game rebuilds the same ground); the ground is drawn from the eye.
- `universe.ground`: the range's site is chosen on land (the free turns of the world about its axis and of the range
  about the star's direction), levelled under the deck; the edge walls are gone.
- `planet_view` near the ground: levels down to 20 (0.3 m quads on an Earth-sized world), each chunk in the depth slice
  its distance calls for, chunks across the local slice's end drawn in both; the planetary slice starts where the local
  one ends, and just short of the ground from high up; a view cone leaves out what cannot be seen; the cloud layer seen
  from afar is a per-vertex amount the draw fades with altitude (no seams between levels).
- Graphics levels gain "Terrain detail" (12, 6, 4 or 3 internal pixels per quad).

## Capabilities

### New Capabilities
- `terrain-streaming`: the world's ground from orbit to the feet, and standing on it.

## Impact

`engine/src/physics/{physics.h,world.c,terrain.c}`, `engine/src/gen/planet.{c,h}`, `engine/src/script/{lua_physics,
lua_planet,lua_gfx}.c`, `engine/src/gfx/{frame.h,frame.c,gl_pipeline.c}`, `data/shaders/gbuffer.glsl`,
`data/scripts/{terrain,planet_view,universe,main,menu}.lua`, `data/scripts/settings/graphics.lua`,
`data/scripts/fk/frames.lua`; sandbox goldens and recorded hashes change on purpose; generators are optimised in
debug builds.
