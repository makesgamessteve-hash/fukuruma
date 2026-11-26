# Proposal

## Why

The concept's look is modern rendering behind a retro filter: physically based light, real shadows and
effects, rendered at a low internal resolution and scaled up with sharp pixels (`docs/CONCEPT.md` §6).
M0 draws unlit vertex colours straight to the window. Every visual feature after this (planets, clouds,
water, animation, the graphics detail levels) builds on this pipeline.

## What Changes

- The scene is rendered into a low-resolution internal image (default 480×270) and shown at the largest
  integer scale that fits the window, centred with black bars, with nearest-neighbour filtering.
- Deferred, physically based shading in HDR: base colour, roughness, metalness and emission per draw;
  a directional star light with cascaded, filtered shadow maps; hemispherical sky/ground ambient light;
  point lights; screen-space ambient occlusion; bloom; automatic exposure with eye adaptation; a filmic
  tone curve; colour grading (exposure bias, contrast, saturation, tint); ordered dithering.
- Supersampling (render at 2× and filter down) for stable pixels; an LDR fallback when the device cannot
  render to float targets.
- An unlit 2D overlay for UI and the touch controls, drawn on the internal image.
- **BREAKING (game scripts):** `fk.gfx.draw(mesh, model, material)` takes a model matrix and a material;
  the camera is set with `fk.gfx.camera(view, projection)`; lights with `fk.gfx.sun`, `fk.gfx.ambient`
  and `fk.gfx.light`; `fk.gfx.overlay(mesh, matrix)` draws unlit 2D; `fk.gfx.configure{...}` sets the
  internal resolution and quality parameters. Meshes may give normals; otherwise they are computed.
- Touch and mouse positions are normalised to the game image, not the window with its bars.
- Screenshots capture the internal image, so reference images do not depend on the window.
- The placeholder scene becomes a lit stage: the Jump Ship hovering over a ground plane with props,
  a warm low sun, a glowing beacon with a point light, shadows and ambient occlusion.

**Out of scope (moved):** bitmap text, the in-game menu, named detail levels, palette mode and temporal
anti-aliasing go to `add-graphics-settings`; image-based lighting from a real sky goes to M4 with the
atmosphere (until then the ambient light is a sky/ground gradient); textures go to `add-asset-loading`.

**Proving game tests:** `tests/game/showcase_lighting.lua` (golden images of the lit stage with HDR,
with supersampling, and with the LDR fallback), plus updated golden images for `boot` and `input`.

## Capabilities

### New Capabilities

- `rendering`: the internal-resolution HDR pipeline, lighting, shadows, effects, overlay and configuration.

### Modified Capabilities

- `script-runtime`: "Drawing from scripts" changes to camera, lights, materials, overlay and configuration.
- `input`: touch and mouse positions are relative to the game image.

## Impact

- New `engine/src/gfx/gl_pipeline.c`, `gfx/frame.c`, `gfx/shadow.c`, `core/mat4.c`; changes to
  `gfx/gl_gfx.c`, `script/script.c`, `app/app.c`.
- New shaders in `data/shaders/`; `data/scripts/main.lua`, `touch_view.lua`, new `shapes.lua`.
- Golden images regenerated on purpose; CI time grows a little (software rendering of more passes).
