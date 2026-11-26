# Proposal

## Why

M1's exit bar is a sandbox that is playable on desktop and phone browsers, with sound, and "already looks modern at
retro resolution". Reviewing the sandbox at the High level showed that temporal anti-aliasing softened the whole
picture, most of all while the camera moves, which at 480×270 shown at 2× is clearly visible. The M1 game tests also
ask for walking with emulated touch input, which the input scenario checked only as a wish, not as movement.

## What Changes

- **Sharper TAA:** the history is read with a Catmull-Rom filter instead of bilinear reads (which blur a little more
  every frame the camera moves); the current frame gets more weight when the picture moves several pixels; and when
  TAA is on, the post pass applies contrast-adaptive sharpening (after AMD's CAS) to the tone-mapped image.
- **Touch walking test:** the input scenario holds the touch stick and checks that the Exosuit walks.
- **Docs:** README status and plan show M1 as done; the owner's open point is the ElevenLabs licence confirmation.

## Capabilities

### Modified Capabilities
- `rendering`: sharp temporal anti-aliasing.
- `input`: the touch stick walks the Exosuit (test).

## Impact

`data/shaders/taa.glsl`, `data/shaders/post.glsl`, `gl_pipeline.c` (a `TAA` define); goldens with TAA on
(`showcase_taa`, `level_medium`, `level_high`, `menu_palette`); `tests/game/input.lua`; `README.md`,
`docs/IMPLEMENTATION_PLAN.md`.
