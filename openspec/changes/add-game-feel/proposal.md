# Proposal

## Why

The concept asks for a game that feels "realistically juicy" (`docs/CONCEPT.md` §6.5), and from M1 on every
player action needs a feedback bundle: sound, particles, light, camera and rumble
(`docs/IMPLEMENTATION_PLAN.md` §3.7 and the look-and-feel bar). The engine has no camera rig, shake,
particles, haptics or comfort options yet, and the scene is still the spinning placeholder ship.

## What Changes

- **The M1 sandbox:** the Exosuit walks and runs over the test range (WASD, arrows, left stick or touch stick;
  sprint with Shift, A or a touch button) and sends a sensor scan (E, X or a touch button). Its movement is
  simulated (arithmetic and square roots only); animation, camera and effects are presentation.
- **Particles:** presentation particles simulated on the CPU (dust, sparks, rings) and drawn in a forward
  pass: lit and alpha-blended dust sorted back to front, glowing particles added; both are occluded by and
  fade softly into the scene using the G-buffer depth. Budgets per detail level.
  `fk.gfx.emit{...}`, `fk.gfx.particles(dt)`.
- **Feedback table** (`data/scripts/feedback.lua`) and **`fk/feel.lua`**: bundles of particles, light
  flashes, camera trauma, hit-pause, rumble and sound for simulation and animation events.
- **Trauma-based camera shake** that falls off with distance and the camera doll's mass.
- **Camera rigs** (`fk/camera.lua`): a chase camera on springs with mass-dependent lag and look-ahead, and a
  first-person camera at a node.
- **Haptics:** `fk.input.rumble(low, high, seconds)` for gamepads, and vibration on phone browsers.
- **Tweens** (`fk/tween.lua`); the settings menu drops in with one.
- **Comfort settings** in the menu: camera shake, light flashes (100%, 50%, off) and rumble (on, off), saved.
- `draw(alpha, dt)`: the game's draw gets the frame time for presentation.

**Out of scope:** decals, motion blur and field-of-view effects (their comfort rows come with them), the
GPU (transform feedback) particle simulation, sound (bundles name sounds; `add-audio` plays them), a camera
the player can orbit.

**Proving game test:** `tests/game/feel.lua` walks the Exosuit (dust at the footsteps, a little shake),
scans (a ring of light, a flash, more shake) against a golden image, and turns the shake off in the comfort
settings.

## Capabilities

### New Capabilities
- `effects`: particles, feedback bundles, camera shake and rigs, hit-pause, haptics, tweens, comfort.

### Modified Capabilities
- `script-runtime`: `draw(alpha, dt)`.
- `graphics-settings`: particle budgets per level.
- `input`: rumble.

## Impact

New `engine/src/fx/particles.{h,c}`, `data/shaders/particle.glsl`, `data/scripts/fk/{feel,camera,tween}.lua`,
`data/scripts/settings/{comfort,store}.lua`, `data/scripts/feedback.lua`; the particle pass in
`gl_pipeline.c`; `main.lua` becomes the sandbox, so the boot, input, menu and lighting goldens and the
recorded simulation hash change.
