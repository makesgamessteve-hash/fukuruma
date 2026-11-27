# Proposal

## Why

M4's core: planets seen from space as real, detailed spheres (CONCEPT §4.4), on a mesh that will carry the
Commander down to the ground in M5, within the draw-call and triangle budgets.

## What Changes

- **Cube-sphere chunks** (`gen/planet.c`): a quadtree on the six faces of an evenly spread cube sphere; a chunk is a
  32 x 32 grid built in a job (`fk.planet`: `planet:chunk(face, level, x, y)`, `request:mesh()`), with positions
  relative to its centre, normals from finite differences (seamless across chunks), skirts, and a hair of overlap.
- **LOD** (`planet_view.lua`): split where a quad would span more than 3 internal pixels; cull behind the horizon;
  draw a chunk until its four children are ready; forget unused chunks; a backstop of the six root chunks; scaled
  space and slices from the frame tree; rings as banded annuli with gaps, lit from the sun's side.
- **Renderer:** `one_sided` draws keep their normals on back faces (closed surfaces); `fk.gfx.stats()` counts draws and
  triangles; auto exposure meters empty sky as at least dim, so a lit planet against space is not blown out.
- **Game test:** one planet of each kind from orbit, with reference images and budgets.

## Capabilities

### New Capabilities
- `planet-rendering`: chunks, LOD, rings, budgets.

### Modified Capabilities
- `rendering`: one-sided draws, frame statistics, exposure metering.

## Impact

`engine/src/gen/planet.{c,h}`, `engine/src/script/{lua_planet,lua_gfx,script}.c`, `engine/src/gfx/{frame,gl_pipeline}.c`,
`frame.h`; `data/shaders/{gbuffer,luminance}.glsl`; `data/scripts/planet_view.lua`; tests `planets_test.lua`,
`tests/game/planets.lua` with eight goldens; other goldens change on purpose (exposure metering).
