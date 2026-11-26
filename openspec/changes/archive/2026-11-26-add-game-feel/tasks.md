# Tasks

## 1. Engine (C)

- [x] 1.1 `fx/particles.c`: emitters (cone, ring, birth sphere), update (gravity, drag, life), budget, own random stream
- [x] 1.2 Particle pass in `gl_pipeline.c` and `particle.glsl`: lit dust sorted back to front, glow added, depth tested and soft
- [x] 1.3 `fk.gfx.emit`, `fk.gfx.particles(dt)`, `max_particles` in the settings
- [x] 1.4 `fk.input.rumble` (SDL gamepads, `navigator.vibrate` on phones)
- [x] 1.5 `draw(alpha, dt)`

## 2. Game (Lua)

- [x] 2.1 `fk/feel.lua`: trauma with falloff, shake, flashes, hit-pause, bundles, listening to simulation events
- [x] 2.2 `fk/camera.lua` (chase and first person), `mat4.look_at`, `mat4.rotation_z`; `fk/tween.lua`
- [x] 2.3 `settings/comfort.lua`, `settings/store.lua`, comfort rows and the pop-in in the menu, particle budgets per level
- [x] 2.4 `feedback.lua` (footstep, scan) and the M1 sandbox in `main.lua`; labelled touch buttons

## 3. Tests

- [x] 3.1 C unit tests: particle cones, rings, motion, budget, determinism
- [x] 3.2 Lua tests: feel, camera, tween, comfort, the sandbox, the menu's comfort rows
- [x] 3.3 `tests/game/feel.lua` with a golden image; input, menu, boot and lighting scenarios moved to the sandbox

## 4. Verification

- [x] 4.1 Coverage gates, sanitizers, all CTest tests, web build and browser tests
- [x] 4.2 CI green on every target; Pages updated
- [x] 4.3 `openspec validate add-game-feel --strict`; archive after deployment
