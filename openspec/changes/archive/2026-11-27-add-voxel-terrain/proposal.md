# Proposal

## Why

The ground should be something the suit can change: dig into, tunnel through, and find again after a load (CONCEPT
§4.5; plan M5: "voxel near field (smooth meshing), terrain deformation with persistent deltas and debris; terrain
collision"; game test: "dig a tunnel, save, reload and walk through it").

## What Changes

- Digs: spheres blasted out of the ground in front of the suit (G, the right shoulder button, or DIG on a touch
  screen), from the surface a pit, from inside one a tunnel forward and down with headroom for the 3.6 m suit. They
  are a simulation component of the current world (saved, hashed; at most 256, the oldest going first; a jump to another
  world leaves them behind); no digging into the deck.
- Physics: the ground with its digs is a solid with a distance field (`fk_terrain_solid`): above the ground its own
  surface unless a dig's opening lies under the point, inside the digs the furthest of their walls or rims; bodies and
  the suit collide with it near digs. `world:digs(list, wake)` (a new dig wakes the bodies; a load does not).
- Meshing: the dug walls by marching tetrahedra (`gen/dig.c`, `planet:dig_mesh`) in 8 m regions of 0.5 m cells, soil
  near the top and rock deeper down; the planet's ground and its shadows leave out what lies inside the nearest 16
  digs (a discard in the G-buffer and shadow passes).
- The dig's feedback: a fountain of earth, dust, an orange flash, a heavy shake and rumble, and an ElevenLabs sound.

## Capabilities

### New Capabilities
- `voxel-terrain`: digging pits and tunnels that last.

## Impact

`engine/src/gen/dig.{c,h}`, `engine/src/physics/{physics.h,terrain.c,world.c}`,
`engine/src/script/{lua_physics,lua_planet,lua_gfx}.c`, `engine/src/gfx/{frame.h,gl_pipeline.c}`,
`data/shaders/{common,gbuffer,shadow}.glsl`, `data/scripts/{dig,main,feedback,touch_view,terrain,planet_view}.lua`,
`data/sounds/dig.ogg`; new `tests/game/dig.lua`.
