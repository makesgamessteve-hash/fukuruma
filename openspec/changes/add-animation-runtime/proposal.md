# Proposal

## Why

The M1 sandbox needs a walking Exosuit: its glTF skin and clips are loaded (`add-asset-loading`) but
nothing plays them. Later dolls, creatures and mechanical sequences build on the same runtime
(`docs/IMPLEMENTATION_PLAN.md` §3.5).

## What Changes

- **Clip sampling and pose blending in C** (`engine/src/anim/`): linear (slerp for rotations), step and
  cubic-spline keys; weighted blends; additive layers; model-space node matrices.
- **GPU skinning:** every skinned draw's bone matrices go into one float texture per frame; the G-buffer
  and shadow vertex shaders blend up to four bones per vertex. Shadows follow the animation.
- **`fk.anim.pose(model)`** with `rest`, `sample(clip, time, weight)`, `add`, `blend`, `copy`,
  `rotate(node, axis, angle)`, `global(node)` and `node(name)`; `fk.gfx.draw(model, m, { pose = p })`.
- **Blend trees and state machines in Lua** (`data/scripts/fk/anim.lua`): 1D blend trees whose clips share
  one phase (walk and run stay in step) and fire events at phases (footsteps); state machines with
  conditions, crossfades and one-shot clips that return to a state.
- **Springs** (`data/scripts/fk/spring.lua`) for secondary motion and camera rigs; the Exosuit gains an
  antenna joint for spring-driven sway.

**Out of scope:** IK, root motion, procedural locomotion and ragdolls (M6 and later), 2D blend trees
(added when a doll needs strafing), morph targets.

**Proving game test:** `tests/game/showcase_skinning.lua` draws the Exosuit idling, walking and running
with a script-turned antenna against a golden image.

## Capabilities

### New Capabilities
- `animation`: poses, clips, blending, skinning, blend trees, state machines, springs.

### Modified Capabilities
- `rendering`: skinned meshes in the G-buffer and shadow passes.

## Impact

New `engine/src/anim/anim.{h,c}`, `engine/src/script/lua_anim.c`, `data/scripts/fk/{anim,spring}.lua`;
bone matrices in `gfx/frame.{h,c}` and `gl_pipeline.c`; skinning in `common.glsl`, `gbuffer.glsl` and
`shadow.glsl`; the Exosuit model gains an antenna joint.
