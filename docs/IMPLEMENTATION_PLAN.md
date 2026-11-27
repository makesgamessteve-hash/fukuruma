# Fukuruma — Implementation Plan

> Status: **v1.2**, 2026-11-26. Based on [CONCEPT.md](CONCEPT.md) v0.5 (modern rendering behind a
> retro-resolution filter, animation and game feel, and the first-person rule: the game is seen only
> through the Commander's eyes; the outside view is for orientation only).
> Each milestone below becomes one or more OpenSpec changes in `openspec/changes/`.
> The first one, `add-project-foundation`, is already written out in full.

---

## 0. Ground Rules

### 0.1 Workflow

- **`main` only.** Every change is committed straight to `main`. There are no feature branches and no
  pull requests. CI runs on every push. The web build is deployed to GitHub Pages only when all CI
  jobs pass, so the last good build stays online when a push breaks something.
- **OpenSpec first.** Every feature goes through: propose → specs → design → tasks → implement →
  `openspec archive`. Change IDs are verb-led (`add-…`, `change-…`, `fix-…`). Capabilities are named
  for durable behaviour (`reference-frames`, `doll-chain`), not for the work.
- **Ponytail** (`AGENTS.md`, from [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)):
  the smallest complete change; no speculative abstractions or options. Extensibility (Lua, mods,
  data folders) and co-op readiness were explicitly requested, so they are in scope. Anything else
  "for later" is not.
- Small commits, each green locally (build, unit tests, game tests) before it is pushed.

### 0.2 Definition of Done (every change)

1. `openspec validate <change> --strict` passes.
2. The implementation follows the ponytail rules; known limits are marked `shortcut: <limit>, <when to upgrade>`.
3. C unit tests and Lua unit tests are written; **line coverage ≥ 95%** for `engine/src` (C) and
   for `data/scripts` (Lua), each gated separately in CI.
4. At least one **automated game test** covers the change's player-visible behaviour.
5. CI is green on Linux, Windows, macOS and Web, and the web build is live on Pages.
6. The change is archived and `openspec/specs/` reflects the new behaviour.
7. `docs/CONCEPT.md` is updated if the design changed.

---

## 1. Technology Choices

| Area | Choice | Licence | Why |
|------|--------|---------|-----|
| Language | C11 (GCC, Clang, MSVC) | — | Requested. Portable to Emscripten. |
| Build | CMake ≥ 3.24 with `CMakePresets.json`, Ninja | — | One build description for all five targets. |
| Platform | SDL 3.4.x, pinned release tarball (SHA-256), built from source (static) | zlib | Window, GL context, input (keyboard, mouse, gamepad, touch), audio, threads, paths. |
| Graphics | OpenGL 3.3 core / OpenGL ES 3.0 / WebGL 2 common subset; deferred, physically based HDR renderer at a low internal resolution | — | Runs on Windows, Linux, macOS (4.1 core) and browsers. The low resolution pays for modern lighting and effects. |
| GL loading | `SDL_GL_GetProcAddress` + one X-macro list of the functions used | — | No generator, no extra dependency. |
| Scripting | Lua 5.4.x, vendored source | MIT | Small, portable, works on WebAssembly (LuaJIT does not). |
| Images | stb_image | PD / MIT | PNG/JPEG textures (PBR material sets, flipbooks, colour-grading tables); mipmaps generated at load. |
| Audio decode | stb_vorbis (OGG); WAV through SDL | PD / MIT | OGG loops seamlessly (MP3 adds gaps). |
| Models | cgltf (glTF 2.0 / .glb) | MIT | Blender exports it; good for modders. |
| Noise | FastNoiseLite (C99 header) | MIT | Simplex, cellular, fractal and domain warp in one header. |
| Animation | in-house runtime on glTF skins and clips (loaded by cgltf) | — | Blending, state machines, IK and springs are small; no C library covers them together. |
| Physics | in-house, deterministic C | — | Characters, vehicles, rigid bodies, ragdolls. The mature 3D engines are C++ (breaks the C requirement) or not deterministic across platforms. |
| Unit tests | utest.h + CTest | Unlicense | A single header, works with every compiler. |
| Coverage | gcov + gcovr (C), luacov (Lua) | BSD / MIT | CI and test builds only. |
| Browser tests | Playwright (Chromium, mobile emulation) | Apache-2.0 | CI only. |
| Web | Emscripten (pinned 4.x), custom JS library for WebXR | MIT | Requested. |
| Audio content | ElevenLabs API (`/v1/sound-generation`, `/v1/music`) through `tools/audio/generate.py` (Python standard library) and ffmpeg to OGG | — | Requested. Prompts are kept in the repo. |
| Specs | OpenSpec 2.x CLI (`@fission-ai/openspec`) | MIT | Requested. |

Every third-party source lives in `third_party/<name>/` with its own licence, and is listed in
`THIRD_PARTY_NOTICES.md`.

**Compiler rules:** `-std=c11 -Wall -Wextra -Werror` in CI (`/W4 /WX` on MSVC), plus
`-ffp-contract=off` (no fused multiply-add) so that generation is deterministic. One CI job builds
with AddressSanitizer and UndefinedBehaviorSanitizer.

**GPU feature baseline.** The common subset of GL 3.3, macOS GL 4.1 and WebGL 2 has **no compute
shaders, no geometry or tessellation shaders and no storage buffers**. It does have multiple render
targets, instancing, uniform buffers, 3D textures and texture arrays, depth textures with hardware
comparison, and transform feedback. All GPU simulation (particles, ocean waves, cloud and fog
volumes) is therefore done with fragment-shader passes into textures and with transform feedback.
HDR render targets need `EXT_color_buffer_float` (or `EXT_color_buffer_half_float`) on WebGL 2;
where neither exists, an LDR fallback path encodes HDR into 8-bit targets.

---

## 2. Repository Layout

```
README.md                  link to the web build at the top
LICENSE                    MIT (code: C, Lua, GLSL, JS, tools)
LICENSE-ASSETS.md          CC BY 4.0 (art: textures, models, voxels, sprites, sounds, music)
THIRD_PARTY_NOTICES.md
AGENTS.md                  ponytail rules (MIT, attributed)
CLAUDE.md                  imports AGENTS.md; project commands and workflow
CMakeLists.txt  CMakePresets.json
engine/
  src/                     one folder per module; headers sit next to their sources
    app/                   main(), CLI (--headless, --test, --scenario, --seed, --no-render)
    core/                  log, arenas, hash + PRNG, jobs, time, commands, entities
    platform/              SDL3 glue: window, GL context, input events, audio device, paths
    gfx/                   GL wrapper, deferred PBR renderer, shadows, atmosphere, clouds, fog,
                           water, particles, decals, post-processing, retro filter, text, UI
    anim/                  skeletons, clips, blending, state machines, IK, springs
    physics/               deterministic collision and dynamics: characters, vehicles, bodies, ragdolls
    present/               game feel: camera rigs and shake, hit-pause, haptics, feedback events
    audio/                 mixer, 3D panning, music layers, decoders
    assets/                VFS (data/ + mods/), loaders (png, gltf, vox, ogg, wav), hot reload
    script/                Lua state, fk.* bindings, sandbox, registries
    world/                 reference frames, orbits, save/load
    gen/                   noise graphs, galaxy, systems, planet fields, terrain chunks,
                           voxels, interiors, creature voxels
data/                      shipped beside the binary
  scripts/                 Lua game (MIT): main.lua, dolls/, gen/, marvels/, ecology/,
                           factions/, economy/, research/, story/, ui/, input/
  shaders/                 GLSL (MIT)
  textures/ materials/ models/ animations/ sprites/ luts/ fonts/ sounds/ music/   (CC BY 4.0)
mods/                      README.md + example-mod/
tests/
  unit/                    C unit tests
  lua/                     Lua unit tests
  game/                    automated game-test scenarios (Lua)
  golden/                  reference screenshots
  determinism/             expected generation hashes
  web/                     Playwright tests
tools/
  audio/                   generate.py + prompts.json (ElevenLabs)
third_party/               lua, stb, cgltf, FastNoiseLite, utest, luacov
web/                       shell.html, fukuruma_web.js (touch detection, WebXR glue), icons
docs/                      CONCEPT.md, IMPLEMENTATION_PLAN.md, later STYLE_GUIDE.md, MODDING.md
openspec/                  config.yaml, specs/, changes/
.github/workflows/ci.yml   build + test matrix + Pages deployment
```

---

## 3. Engine Architecture

### 3.1 Layers

```
            ┌──────────────────────────────────────────────────────┐
  Lua game  │ dolls · generation recipes · Wonder Director · AI ·  │  data/scripts (moddable)
            │ factions · economy · research · story · UI layout    │
            └───────────────▲──────────────────────────────────────┘
                            │ fk.* API (script/)
  C engine  ┌───────────────┴──────────────────────────────────────┐
            │ world/ physics/ anim/ gen/ gfx/ present/ audio/      │
            │ assets/  (testable; GL only in gfx/gl_*.c)           │
            │ core/  (hash, PRNG, jobs, commands, entities, log)   │
            └───────────────▲──────────────────────────────────────┘
                            │ the only layer that calls SDL directly
            ┌───────────────┴──────────────────────────────────────┐
            │ platform/ (SDL3 window, events, audio device, paths) │
            └──────────────────────────────────────────────────────┘
```

Only `platform/` calls SDL, and only `gfx/gl_*.c` calls OpenGL. Everything else is plain C that unit
tests can run without a window. This is what makes 95% coverage reachable.

### 3.2 Main loop, simulation and commands (co-op ready)

- A fixed **60 Hz simulation tick**. Rendering interpolates between ticks and runs at the display rate.
- Simulation state changes only through **commands** (`fk_cmd`: a type, an entity ID and a small
  payload), queued from input, Lua and AI and applied in order at the start of each tick.
- Entities have **stable 64-bit IDs** and component storage in sparse sets. The Commander is an
  entity. There are no pointers in saved state.
- Random numbers come from **named streams** (`hash(world_seed, stream, tick)`), never from a global RNG.
- Together this gives replays, reproducible game tests and, later, co-op (commands are what travels
  over the network) without any networking code now.
- **Simulation vs. presentation.** The simulation (commands, gameplay physics, AI, generation)
  emits **events** (footstep, impact, deploy stage, discovery, damage). The presentation layer
  (rendering, animation blending, particles, camera rigs, hit-pause, haptics, audio) consumes them and
  never writes back. Hit-pause slows only presentation time. Presentation randomness comes from its
  own seeded streams, so game-test screenshots stay reproducible.
- A **job system** uses worker threads on desktop. On the web it falls back to a time-sliced queue on
  the main thread, because GitHub Pages cannot send the COOP/COEP headers that WebAssembly threads
  need. Generation has a per-frame time budget.

### 3.3 Reference frames and scale

The same game must be precise for a 1 cm spore and a 144 km Jump Ship in a system 100 AU across.

- **Frame tree:** galaxy sector → star system → body (star, planet, moon) → vessel (doll) →
  interior sector or surface patch. Every object lives in exactly one frame.
- **Positions:** `double` inside a system (at 100 AU, a double still resolves about 3 mm). Galaxy
  positions are an integer sector plus a double offset. Physics and rendering work in `float`,
  relative to the local frame or the camera.
- **Camera-relative rendering:** every frame, object positions are turned into camera-relative
  floats on the CPU in double precision, so nothing jitters far from the origin.
- **Depth slices:** celestial → planetary → local. Each slice has its own projection, and the depth
  buffer is cleared between slices. This works on WebGL 2 without `glClipControl` or logarithmic depth.
- **Scaled space:** bodies beyond a threshold are drawn shrunk and moved closer by the same factor,
  so their angular size is correct.
- **Frame transitions:** boarding, docking, entering an atmosphere or a hangar re-parents the
  entity, keeping its world position and velocity.
- **Orbits:** Kepler elements on rails, solved with Newton iteration on the eccentric anomaly.

### 3.4 Rendering: modern techniques at retro resolution

**Principle:** everything is rendered with modern, physically based techniques into a low-resolution
HDR target, which is then scaled to the screen with sharp pixels. Per-pixel cost falls with the
square of the resolution (480×270 is 1/16 of 1080p), so the budget goes into lighting, shadows,
volumes and effects. Geometry LOD is chosen by projected size in **internal** pixels, so detail
that would fall below one internal pixel is never drawn.

**Internal resolution presets:** Classic 480×270, Sharp 640×360, Fine 960×540, plus a per-eye VR
preset.

**Graphics detail levels** (Low, Medium, High, Ultra, Custom; see `CONCEPT.md` §6.2 for the
player-facing table) are switched in the in-game menu and apply **live**:
- A level is a Lua table in `data/scripts/settings/graphics.lua`: shadow cascades and map size,
  shadowed-light count, local-light limit, AO quality, cloud and fog march steps and volume size,
  water mode, particle budget, post effects, anti-aliasing, and an LOD bias. Levels vary mostly
  the lighting, shadow and effect rows; the LOD bias only ranges from 0.8 (Low) to 1.0, so models
  look the same on every level.
- Switching a level recompiles only the shader variants whose `#define`s changed (cached per
  variant) and reallocates only the render targets whose size changed, spread over a few frames so the
  scene behind the menu keeps running.
- The default level comes from the device class (the `GL_RENDERER` string, mobile or desktop, XR
  session) and is saved in the settings file (`SDL_GetPrefPath()`, IndexedDB on the web).
- The fixed `ci` level is used by game tests, so golden images do not depend on the device.

Frame structure (each pass at the internal resolution unless noted):

1. **Shadow maps:** 3–4 texel-snapped cascades per star (two sets for binary stars) with filtered
   soft shadows; one far cascade for doll-sized casters; a shadow atlas for a few local spot and point
   lights. Eclipse, ring and planet shadows are analytic.
2. **Sky and atmosphere:** precomputed scattering tables (transmittance, multiple scattering, sky
   view, aerial perspective as a small 3D texture) for the current atmosphere; the system's HDR sky
   cube map; a prefiltered environment map for image-based lighting, refreshed over several frames.
3. **G-buffer (deferred):** base colour, normal, roughness / metalness / occlusion, emission and
   motion vectors, written by opaque geometry (models, terrain chunks, voxel meshes, instanced
   vegetation with wind animation, skinned characters, decals).
4. **Screen-space passes:** ambient occlusion, contact shadows, screen-space reflections with
   environment-map fallback.
5. **Lighting:** physically based (GGX) shading of the star(s) with shadows and atmospheric
   transmittance, many local lights in a tiled light list, image-based ambient light and planetshine.
6. **Volumes:** ray-marched volumetric clouds (half internal resolution, reprojected over frames);
   a froxel fog volume (for example 160×90×64) holding height fog and local volumes (smoke, dust,
   steam, spores, toxic gas), lit and shadowed, which also produces light shafts.
7. **Forward pass for transparent things:** water (wave displacement from fragment-shader FFT
   textures, reflection, refraction, depth colour, foam, caustics, underwater fog), particles
   (simulated with transform feedback; soft, lit, sorted per emitter; fire, smoke, sparks, rain, snow,
   dust, debris), glass, holograms, heat distortion.
8. **Post-processing:** temporal anti-aliasing or 2×2 supersample resolve, motion blur and depth of
   field (optional), bloom, lens flares, automatic exposure, filmic tone mapping, per-world colour
   grading (a 3D lookup table generated from the world's data), optional ordered dither and palette mode.
9. **Retro upscale:** integer nearest-neighbour scaling to the window (sharp-bilinear for
   non-integer ratios).
10. **UI:** pixel fonts and widgets at a multiple of the internal resolution (native-resolution text
    as an accessibility option); diegetic screens are rendered into textures in the 3D world.

**First-person rendering** (the game is always seen from the Commander's eyes, `CONCEPT.md` §2.6):
- The **near layer** (the Commander's arms and hands, the Exosuit's helmet rim, the cockpit and its
  instruments) is drawn in its own depth partition with a near plane of a few centimetres, before the
  world, so it never clips into walls or terrain and the far world keeps its depth precision. It
  shares the G-buffer, lighting and shadows with the world, so sunlight falls through the windows onto
  the dashboard.
- **Canopies and windows** are drawn in the forward pass: thin glass with reflections from the
  environment map, dirt, rain streaks, dust and frost layers, and scan markings projected onto them.
- **The visor** is a screen-space layer after post-processing: the HUD (at a multiple of the internal
  resolution), edge distortion, condensation, cracks and glitches when the suit is damaged.
- **Cockpit screens** (map, sensors, external cameras, menus) are render targets drawn into the
  cockpit as emissive materials; the external-camera and outside-view feeds render the scene a second
  time at a lower resolution, within the detail level's budget.

**Pixel stability** (detailed geometry at low resolution shimmers): supersampling or temporal
anti-aliasing, texel-snapped shadow cascades, mip bias tuned for the internal resolution, and
specular anti-aliasing (roughness widened by normal variance).

Shaders live in `data/shaders/*.glsl`. The engine prepends the right `#version` line, precision
qualifiers and quality-preset defines. In VR, each eye goes through the same pipeline into the XR
framebuffer.

### 3.5 Animation

- **Skeletal:** glTF skins and clips; GPU skinning (bone matrices in a uniform buffer or texture);
  clip sampling with compressed keys.
- **Blending:** blend trees (1D and 2D), layered state machines defined in Lua, additive layers
  (breathing, recoil, flinch), root motion feeding the character controller.
- **IK:** two-bone and FABRIK solvers; foot placement on terrain for the Walker and the Land
  Explorer, with body height and tilt from the planted feet; hand IK for Exosuit controls and climbing;
  look-at for creatures and natives.
- **Procedural locomotion:** for generated creatures, gait patterns (phase offsets per leg), step
  targets from velocity and terrain, a spine that follows the path, tails and necks on springs.
- **Secondary motion:** damped springs and Verlet chains for cables, antennae, tails, fins and
  cloth-like parts (presentation only); ragdolls from the same Verlet system when a creature dies.
- **Mechanical sequences:** Lua timelines that drive joints (doors, clamps, ramps, legs folding) and
  fire events at keyed times (sounds, lights, particles, camera beats).

### 3.6 Physics

- Deterministic C, fixed 60 Hz step inside the simulation, no external engine.
- **Shapes:** sphere, capsule, box, convex hull, triangle mesh, heightfield chunk, voxel chunk.
  A broadphase grid per reference frame.
- **Characters:** kinematic capsule controller with steps, slopes, jump jets and climbing.
- **Vehicles:** ray-cast suspension for wheeled and tracked machines; legged dolls move by their
  animation (IK) on a physical body that handles collisions and momentum; flying dolls with simple
  aerodynamic forces.
- **Rigid bodies:** sequential-impulse solver for debris, props and cargo, with sleeping; budgets on
  active bodies per area.
- Visual-only motion (foliage, cables, sparks) is not in the physics module; it runs in presentation.

### 3.7 Game feel (the presentation layer)

- **First-person rigs, no chase camera:** the *helmet rig* (the Exosuit's head node: free look within
  the helmet's limits, head bob and sway from the suit's gait and mass) and the *seat rig* (a doll's
  cockpit seat: free look within the seat's limits, head lag and settle from the doll's acceleration,
  cabin sway from its motion). Looking and steering are separate inputs. A horizon-steady option
  counter-rotates the view against cabin roll.
- **The orientation view:** the survey drone's feed, an orbit around the current doll at a distance
  scaled to its size, with turn, zoom and waypoint marking only. While it is open, the movement and
  action inputs are inactive and the doll holds its course or keeps flying its autopilot; one button
  returns to the Commander's eyes. It closes itself when the Commander takes damage.
- **Trauma-based camera shake:** events add trauma with a source position and strength; the
  camera's shake falls off with distance and the doll's mass (a Walker's footstep at 50 m shakes the
  Exosuit, not the Land Explorer).
- **Feedback table in Lua:** each simulation event maps to a bundle: sound, particles, light flash,
  camera trauma, hit-pause, rumble, decal. Designers and modders tune the feel without touching C.
- **Haptics:** SDL gamepad rumble and trigger rumble, `navigator.vibrate` on phones, XR controller
  haptic actuators.
- **Tweens and springs** for UI, HUD and diegetic screens.
- **Comfort settings** scale shake, flashes, head bob, cabin sway, motion blur and field-of-view
  effects, set the field of view, switch the horizon-steady option and a turning vignette; in VR the
  head is never moved by effects.

### 3.8 Procedural generation

- **Seeds:** `seed(child) = hash64(seed(parent), kind, index)`. Every object can be regenerated on its
  own, in any order, on any thread.
- **Noise graphs:** Lua archetypes describe terrain as a table of nodes (sources, combiners, warps,
  curves). The C side compiles the table once into a flat node array and evaluates it in tight loops.
  Modders can write new planet types without touching C.
- **Pipeline:** galaxy density → sector stars → star system (stars, orbits, bodies) → Wonder Director
  (Lua) → planet descriptor → global fields (cube-sphere grid) → chunk heightfields (quadtree) →
  near-field voxels → scatter → populations.
- **Caching:** generated chunks are kept in an LRU cache; **player edits are deltas** stored per chunk
  or per sector and applied after generation.
- **Determinism:** generation only uses `+ − × ÷ sqrt` (exact in IEEE 754) and in-house approximations
  for `sin`, `cos`, `exp`, `pow` and `atan2`. CI compares generation hashes on every platform.

### 3.9 Interiors

- Hull: a Lua definition that names a model, a bounding volume and a zone list.
- Zones are placed in the hull volume by a grammar (Lua). Each zone fills **sectors** (fixed cubes,
  for example 64 m). Each sector is a tile grid (2 m cells, 6 m clear height for the Exosuit) filled
  with detailed kit pieces (rooms, corridors, shafts, hangar walls), lit by their own fixtures, with
  baked-at-generation light probes for ambient light.
- Sectors are generated by jobs when the Commander comes within N sectors, and unloaded beyond N+2.
- Hand-authored rooms (bridge, clone bay, research deck) are Lua/voxel files that override the grammar.
- **Cockpits and bridges** are part of every doll's definition: the seat position (the seat rig's
  eye point and look limits), the controls the Commander's hands reach for, the windows, and the
  screens with what they show. They are detailed kit models, the most-seen geometry in the game.
- Transit: lifts, trams on zone spines, teleport pads. Hangars show the docked child dolls at full scale.

### 3.10 The Lua layer

- `fk.*` modules: `log`, `time`, `input`, `gfx`, `audio`, `vfs`, `ui`, `ent`, `cmd`, `frame`, `gen`,
  `save`, `rng`.
- **Registries:** `fk.register("doll" | "archetype" | "marvel" | "species" | "faction" | "item" |
  "recipe" | "research" | ..., def)`. Base game and mods use the same calls.
- **Sandbox:** scripts get no `os`, no `io` and no `debug`, only `fk.vfs`, so mods cannot touch the user's files.
- **Hot reload** of scripts and shaders on desktop debug builds.
- **Performance rules:** Lua makes decisions (AI at 2–10 Hz, events, UI). It never runs per-vertex or
  per-voxel code. Crowds are simulated in C with Lua-defined parameters.

Example: a doll definition.

```lua
-- data/scripts/dolls/walker.lua
fk.register("doll", {
  id = "walker",
  name = "Exploration Walker",
  height_m = 72,
  hull = "models/dolls/walker.glb",
  controller = "legged",
  carries = { exosuit = 1 },
  deploy = { from = "land_explorer", needs = "surface" },
  sensors = { range_m = 2000, resolution_m = 0.5, kinds = { "thermal", "bio", "seismic" } },
})
```

Example: a marvel.

```lua
-- data/scripts/marvels/polar_ring.lua
fk.register("marvel", {
  id = "polar_ring",
  rarity = 0.04,
  requires = function(body) return body.radius_km > 4000 end,
  apply = function(body, rng)
    body.rings = { inclination_deg = 80 + rng:range(0, 10), inner = 1.6, outer = 2.4 }
  end,
  signature = { kind = "visual", size_km = 40000 },
  codex = "codex/marvels/polar_ring",
})
```

### 3.11 Assets, mods and saves

- **VFS:** the search order is `mods/<load order>/` → `data/`. Paths are resolved with `SDL_GetBasePath()`.
  On the web, `data/` is packaged by Emscripten as `fukuruma.data` next to `fukuruma.wasm`.
- **Mods:** `mods/<name>/mod.lua` holds the name, version, load order and dependencies. A mod can
  add or replace files and register new content.
- **Saves:** the world seed plus all deltas (chunk edits, interior sectors, entities, factions,
  economy, codex), written as versioned Lua-table text. They are stored in `SDL_GetPrefPath()`, and
  on the web in IndexedDB (IDBFS).

### 3.12 Audio

- A mixer on SDL3 audio streams: one-shot and looping sources, 3D panning and attenuation,
  per-category volumes, and music **layers** that crossfade by situation (deep space, orbit,
  surface, danger, discovery).
- `tools/audio/generate.py` reads `tools/audio/prompts.json` (ID, sound effect or music, prompt,
  length, loop flag, target path). It calls ElevenLabs only for entries whose prompt hash changed,
  converts the result to OGG Vorbis with ffmpeg, and records provenance in `data/sounds/CREDITS.md`
  and `data/music/CREDITS.md`.
- Facts from ElevenLabs' public docs (to be re-checked when the tool is written): sound effects
  are 0.5–30 s, with a `loop` option on the v2 model; music is 3 s to 10 min.

### 3.13 Input and platforms

- **Action maps** in Lua (`data/scripts/input/*.lua`): actions such as `move`, `look`, `steer`,
  `throttle`, `deploy`, `scan`, `board`, `seat` (take or leave the controls) and `outside_view`, bound
  per device and per doll. Players can remap them. Mouse look uses relative mouse mode on desktop and
  pointer lock in the browser; gamepads look with the right stick; touch looks by dragging on the right
  half of the screen.
- **Touch:** the engine reports when touch input becomes active (`SDL_EVENT_FINGER_*`, plus
  `pointer: coarse` on the web). Lua then shows the touch layout: a virtual stick, a look-drag area
  and context buttons sized for thumbs. The layout switches back on keyboard or gamepad input.
- **WebXR:** `web/fukuruma_web.js` (an Emscripten `--js-library`) starts an `immersive-vr` session,
  passes the eye views, projections and controller poses to C each frame, and binds the XR
  framebuffer. C renders both eyes. Comfort options: snap or smooth turning, teleport locomotion
  and a vignette. The HUD is drawn on the visor.

---

## 4. Testing Strategy

| Layer | What | Tool | Gate |
|-------|------|------|------|
| C unit | every module in `engine/src` | utest.h + CTest | all pass |
| Lua unit | every module in `data/scripts` | `fukuruma --test tests/lua` | all pass |
| Coverage | C lines (unit + game tests, Linux/GCC) | gcovr `--fail-under-line 95` | ≥ 95% |
| Coverage | Lua lines | luacov | ≥ 95% |
| Game tests | scripted scenarios, headless, deterministic | `fukuruma --headless --scenario` | all pass |
| Visual | golden screenshots at the internal resolution with the `ci` quality preset | built into the scenario runner | ≤ 0.5% pixels differ |
| Effects showcase | one fixed scene per technique: shadows, atmosphere, clouds, fog, water, fire, smoke, particles, skinning, IK | scenarios in `tests/game/showcase/` | golden images + budgets |
| Animation | IK reach and foot-placement error, blend weights, clip sampling | C unit tests | within tolerances |
| Physics | stacking, sliding, suspension, determinism of 10,000 steps | C unit tests | identical hashes on all platforms |
| Determinism | generation hashes | `fukuruma --gen-hash` | identical on all platforms |
| Web | page loads, scenario passes, touch UI, WebXR start | Playwright | all pass |
| Safety | ASan + UBSan build of the unit tests | Clang | no reports |

**Automated game tests.** A scenario is a Lua file that drives the real game through commands and
simulated input, with fixed seeds and fixed time steps:

```lua
-- tests/game/fukuruma_chain.lua
return scenario {
  seed = 42,
  timeout_s = 900,
  run = function(t)
    t.jump_to_system(3)
    t.deploy("station", { planet = 2 });         t.teleport("station")
    t.deploy("continental_explorer", { lat = 12, lon = 40 })
    t.board("drop_ship");                        t.fly_to("continental_explorer")
    t.deploy("land_explorer");                   t.deploy("walker")
    t.disembark();                               t.walk({ 100, 0 })
    t.expect(t.commander().doll == "exosuit")
    t.screenshot("chain_exosuit")                -- compared to tests/golden/
    t.recall_all();                              t.expect(t.commander().doll == "jump_ship")
  end,
}
```

- Rendering scenarios run on Linux with Mesa **llvmpipe** (SDL's offscreen video driver with EGL),
  and in Chromium (SwiftShader) for the web. Windows and macOS runners have no reliable GPU, so
  there the same scenarios run with `--no-render`, which checks logic and determinism.
- Golden images are updated with `--update-golden`, and the diff images are uploaded as CI artifacts.
- Temporal effects (anti-aliasing, cloud reprojection, auto exposure) are reproducible in tests: the
  time step is fixed, noise is indexed by frame number, and history buffers are reset when a scenario
  starts. The `ci` quality preset keeps ray-march steps low enough for llvmpipe.
- The showcase scenes are also selectable from a *Showcase* menu in the web build, so progress on
  the look can be checked in the browser.
- **The first-person rule is tested:** game tests check that the active camera is the helmet or a
  seat rig (never anything else during play), that movement and action inputs do nothing while the
  outside view is open, and that the outside view closes when the Commander takes damage.
- Budgets are checked by counters, not frame times (CI machines vary): draw calls, triangles, chunk
  generation milliseconds per frame, memory. Real frame rates are checked by hand on the target
  devices at the end of each milestone.

**Target devices (assumed, adjustable):** a laptop with integrated graphics at 60 fps; a mid-range
2023 phone in Chrome or Safari at 30 fps; Meta Quest 3 browser at 72 fps.

**Local commands** (also listed in `CLAUDE.md`):

```bash
cmake --preset linux-debug && cmake --build --preset linux-debug && ctest --preset linux-debug
```

```bash
cmake --preset linux-coverage && cmake --build --preset linux-coverage && cmake --build --preset linux-coverage --target coverage
```

```bash
cmake --preset web && cmake --build --preset web && npx playwright test tests/web
```

---

## 5. CI/CD

A single workflow, `.github/workflows/ci.yml`, runs on every push to `main` and on manual dispatch:

| Job | Runner | Steps |
|-----|--------|-------|
| `specs` | ubuntu | `openspec validate --all --strict` |
| `linux` | ubuntu | GCC coverage build → unit tests → Lua tests → game tests on llvmpipe → coverage gates → upload golden diffs on failure |
| `sanitize` | ubuntu | Clang ASan + UBSan → unit tests |
| `windows` | windows | MSVC build → unit tests → `--no-render` scenarios → determinism hashes |
| `macos` | macos | Clang build → unit tests → `--no-render` scenarios → determinism hashes |
| `web` | ubuntu | emsdk (pinned) → web build → Playwright (desktop, mobile touch, mocked WebXR) → determinism hashes in the browser |
| `pages` | ubuntu | needs every job above → `actions/upload-pages-artifact` → `actions/deploy-pages` |

Release builds: pushing a tag `v*` runs a release job that zips each desktop build as
`fukuruma(.exe)` + `data/` + `mods/` + licences, and attaches the zips to a GitHub Release.

**One-time setup by the repository owner:** GitHub → *Settings → Pages → Build and deployment →
Source: GitHub Actions*. The site will be at <https://makesgamessteve-hash.github.io/fukuruma/>.

---

## 6. Milestones

Sizes are relative (S < M < L < XL). Each milestone ends with a playable build on Pages. Order:
foundation → engine → scale → universe → planets → **the Fukuruma vertical slice (M6)** →
platforms → depth.

**Look-and-feel bar (every milestone from M1 on):** new content meets the rendering standard
(PBR materials, correct shadows, effects for every interaction), and the milestone ends with a
**juice pass**: every new action has its feedback bundle (sound, particles, light, camera, rumble),
and the showcase scenes are reviewed on desktop, phone and VR.

### M0 — Foundation and pipeline (M)

- **OpenSpec:** `add-project-foundation` (written; see `openspec/changes/add-project-foundation/`).
- **Capabilities:** `asset-layout`, `script-runtime`, `test-harness`, `web-distribution`.
- **Work:** repository layout, licences, README, AGENTS.md and CLAUDE.md; CMake presets for five
  targets; SDL3 window and GL context; GL loader; Lua VM running `data/scripts/main.lua`, which draws a
  spinning placeholder model through `fk.gfx`; minimal VFS; CLI (`--headless`, `--test`,
  `--scenario`, `--seed`, `--no-render`); utest, luacov and gcovr gates; the CI workflow; Pages
  deployment; Playwright smoke test.
- **Game test:** `boot.lua`: start, render 120 frames, match the golden image, exit 0.
- **Exit:** Pages shows the placeholder; CI is green on all targets; coverage ≥ 95%.

### M1 — Engine core (XL)

- **OpenSpec:** `add-simulation-loop` (fixed tick, commands, events, entities, named RNG streams,
  state hash; done), `add-input-actions` (action maps, keyboard, mouse, gamepad, touch detection and a basic
  virtual stick; done), `add-render-pipeline` (low-resolution HDR target and integer upscale, deferred PBR,
  star light with cascaded shadows, sky/ground ambient, point lights, ambient occlusion, bloom, auto
  exposure, tone mapping, colour grading, dithering, supersampling, LDR fallback, overlay, runtime
  configuration, screenshots; done), `add-graphics-settings` (detail levels Low, Medium, High,
  Ultra and Custom, bitmap text and immediate UI, the in-game *Settings → Graphics* menu, live
  switching, temporal anti-aliasing, palette mode, an internal resolution that fills the window,
  device defaults, saved settings; done), `add-asset-loading` (PNG and JPEG with mipmaps, glTF meshes, materials,
  skins and clips, OGG, WAV, hot reload; done), `add-animation-runtime` (skinning, blend trees, state
  machines, springs; done), `add-game-feel` (presentation layer: camera rigs, trauma shake, feedback table,
  haptics, tweens, comfort settings, particles; done), `add-audio` (mixer, 3D, reverb zones, music layers, the
  ElevenLabs tool and a first set of sounds; done), `add-save-system` (snapshot and deltas, IDBFS, versioning;
  done), `polish-m1-sandbox` (sharp TAA, touch walking test). The M1 sandbox still uses a chase
  camera; `add-first-person-view` (M2) moves it to the Commander's eyes.
- **Game tests:** a sandbox scene: a skinned placeholder Exosuit walks across a lit, shadowed test
  ground with keyboard input and with emulated touch input; a save/load round-trip keeps its
  position; showcase scenes for shadows, materials and skinning match their golden images; the
  graphics menu switches through all four levels while the scene keeps running, with one golden
  image per level.
- **Exit:** the sandbox is playable on desktop and phone browsers, with sound, and already looks
  modern at retro resolution.

### M2 — Reference frames and scale (M)

- **OpenSpec:** `add-first-person-view` (first; done), `add-reference-frames` (frame tree in doubles, transitions,
  camera-relative drawing, depth slices by depth range, scaled space, scale ladder; done), `add-orbital-mechanics`
  (deterministic trigonometry, Kepler orbits on rails, spinning frames; done), `add-physics` (spheres, capsules,
  boxes, broadphase grid, sequential impulses with warm starting, sleeping islands, gravity per body, characters with
  steps and slopes, exact saves; the Exosuit pushes crates; done). Left for later milestones: convex hulls, triangle
  meshes, heightfield and voxel chunks (with terrain, M5), vehicles (M6), jump jets and climbing.
- **`add-first-person-view`:** the M1 sandbox becomes first person: the helmet rig in the Exosuit's
  head (mouse, right-stick and touch look; head bob and sway), the visor as a screen-space layer with
  a first HUD (heading, speed, scan pulse), the suit's arms in the near layer (placeholder hands),
  movement relative to where the Commander looks, the orientation view as a drone orbit around the
  suit with movement disabled, and comfort settings for head bob, field of view and the turning
  vignette. Game tests: walking and scanning in first person, the outside view ignores movement,
  golden images of the helmet view and of the orientation view.
- **Work:** the frame tree, double positions, camera-relative transforms, depth slices (including the
  near layer for cockpits and hands), scaled space,
  frame transitions, Kepler orbits; deterministic physics (shapes, broadphase per frame, character
  controller, rigid bodies), gravity per body.
- **Game test:** the *scale ladder*: the camera moves from a 1 m cube to a 144 km hull to a planet to
  a star. A golden image at each step; position jitter < 1 mm at 100 AU from the star.

### M3 — Galaxy and star systems (L)

- **OpenSpec:** `add-job-system` (worker threads on desktop, time-sliced on the web; moved here from M1
  because generation is the first background work; done), `add-galaxy-generation` (density, sectors, star physics,
  deterministic exp/log/atan2/pow; done), `add-star-systems` (the eleven archetypes, Hill-spaced orbits, moons, rings,
  belts, comets, 16 classes; done), `add-wonder-director` (22 marvels, rarity within 20%; done), `add-navigation-maps`
  (the real sky baked from the stars, the range on a world of the current system, galaxy and system maps, the jump;
  done). The Jump Ship's own bridge and seat come with the doll chain (M6); until then the maps open from the suit.
- **Work:** hash and PRNG hierarchy, galaxy density and sector stars, star physics, the eleven system
  archetypes, orbits, moons, rings, belts and comets, Lua archetype registry, the Wonder Director
  with at least 10 marvels, galaxy and system maps, skybox baking, the jump sequence.
- **Tests:** statistical unit tests over 10,000 systems (no unstable orbits; at least one marvel per
  system; target rarity ±20%); determinism hashes on all platforms; a game test that jumps through
  three systems.

### M4 — Planets from space (L)

- **OpenSpec:** `add-noise-graphs`, `add-planet-descriptors`, `add-planet-rendering`,
  `add-atmospheric-scattering`, `add-star-rendering` (all done).
- **Work:** the noise-graph DSL and evaluator, global fields (plates, elevation, climate, biomes),
  planet materials from the fields, cube-sphere LOD, physically based atmospheres per composition,
  image-based lighting from the real sky (replacing M1's sky/ground ambient gradient),
  cloud layers from orbit, night lights, rings with forward scattering and shadows, eclipses and
  planetshine, per-world colour grading, HDR stars with convection, corona, bloom and flares, binary
  lighting, the first marvel visuals (polar ring, black hole lensing, pulsar beam).
- **Game test:** orbit one planet of each archetype; golden images; draw-call and triangle budgets.

### M5 — Seamless surfaces (XL)

- **OpenSpec:** `add-terrain-streaming` (done: chunks to 0.3 m quads, terrain collision, the range on land),
  `add-terrain-materials` (done), `add-biomes-and-scatter` (done), `add-voxel-terrain` (done: dug spheres the
  physics and the ground share, saved; `fix-dig-tunnels`: tunnels of any length, lit by the helmet lamp), `add-volumetric-clouds-and-fog` (done), `add-water` (done: the sea, its floor
  and caustics), `add-weather` (done).
- **Still open in M5:** rivers, waterfalls and lakes above sea level (they need water courses in the world's data),
  impostors for distant flora, debris from digging, time-sliced generation on the web, and the showcase scenes for
  rivers and light shafts. Known rough edges: the dug walls are smooth and untextured, and cloud edges are grainy
  without TAA.
- **Work:** quadtree chunk streaming from orbit to the ground without cracks, regional detail,
  triplanar terrain materials with wetness, snow and dust layers; biome scatter (instanced detailed
  flora and rocks with wind animation and impostors); voxel near field (smooth meshing),
  **terrain deformation** with persistent deltas and debris; terrain collision; volumetric clouds
  with cloud shadows, the froxel fog volume and light shafts; oceans, lakes, rivers and waterfalls
  with waves, reflections, refraction, foam, caustics and underwater fog; day and night; rain, snow,
  sandstorms and lightning; time-sliced generation on the web.
- **Game tests:** a descent from station orbit to the ground in one continuous flight (no holes, within
  budget); dig a tunnel, save, reload and walk through it; chunk determinism hashes; showcase scenes
  for clouds, fog and light shafts, ocean, river and rain.

### M6 — The Fukuruma chain: vertical slice (XL)

- **OpenSpec:** `add-doll-chain`, `add-vehicle-controllers`, `add-teleport-network`, `add-autopilot`.
- **Work:** the doll registry and schema, detailed procedural hulls for the seven dolls and the Drop
  Ship (part grammar with greebles, PBR materials, lights), deploy / recall / board / disembark as
  choreographed mechanical sequences watched from the cockpit, on its screens or in the orientation
  view, one controller per doll steered from its seat (jump drive, orbit, flight, crawl, legged
  locomotion with foot IK on terrain, first-person Exosuit with arms), the teleport network, a
  detailed cockpit or bridge for every doll with diegetic screens and the Commander's hands on the
  controls, seat rigs with each doll's sway, the orientation view per doll, boarding and disembarking
  walked in first person (with a "go to the controls" sequence), autopilot with time compression that
  frees the Commander to leave the seat, ship-AI text lines, and the feedback bundles that make each
  doll feel its mass from inside (cabin jolts on footsteps, rattling instruments, engine rumble,
  landing impacts).
- **Game test:** *the Fukuruma test*: the whole chain down and back up (see §4), entirely in first
  person: every doll is boarded on foot and steered from its seat. It runs on every push from now on.
- **Exit:** the vertical slice is playable on Pages: one system, one planet, every doll.

### M7 — Touch and WebXR (L)

- **OpenSpec:** `add-touch-controls`, `add-webxr`.
- **Work:** a touch layout per doll (move or steer on the left, look-drag on the right, context
  buttons), UI scaling, the WebXR session, stereo rendering with the VR resolution preset, controller
  mapping and haptics, comfort options, the visor HUD, cockpits in VR (the player's head is the
  Commander's head; the orientation view becomes a holographic miniature of the doll and its
  surroundings on the dashboard, so the VR view never moves on its own),
  performance tuning for Quest-class devices (quality presets, fixed foveation where the browser
  offers it).
- **Tests:** Playwright with phone emulation (touch layout, the stick moves the Commander); a mocked
  `navigator.xr` (button visibility, session start path); a golden image of the side-by-side stereo
  debug view.

### M8 — Interiors (L)

- **OpenSpec:** `add-vessel-interiors`, `add-interior-transit`, `add-drones`.
- **Work:** hull zones, the sector grammar, kit pieces, streaming and unloading, delta persistence,
  lifts, trams and pads, hangars with docked dolls, ambient drones, the hand-authored bridge and clone bay.
- **Game test:** walk from the Jump Ship bridge to a station hangar by tram; visit 50 sectors within
  the memory budget; door states survive a save and reload.

### M9 — Sensors and scanning (M)

- **OpenSpec:** `add-sensor-system`, `add-scan-overlays`, `add-exosuit-hud`.
- **Work:** the signature model, a sensor suite per doll, passive and active scans, ageing scan data,
  scan markings drawn onto the windows and the visor (augmented reality) and on the cockpit's sensor
  screens, map overlays, autopilot hazard stops, the visor HUD.
- **Game tests:** a hazard below the Walker's resolution is invisible to the Walker and visible to the
  Exosuit; an active ping alerts a hostile; autopilot stops at a detected sinkhole.

### M10 — Hazards, survival and life (XL)

- **OpenSpec:** `add-environment-model`, `add-exosuit-survival`, `add-death-modes`, `add-ecology`,
  `add-creature-generation`, `add-procedural-animation`, `add-fire-and-destruction`,
  `add-defensive-tools`.
- **Work:** atmosphere, pressure, temperature, radiation and toxins; terrain hazards; Exosuit systems
  and doll damage (visible on hulls and the visor); Clone mode and Legacy mode; procedural flora
  and fauna (body-plan grammar → skinned mesh with PBR materials → procedural gaits, secondary motion
  and ragdolls); ecology tables per biome; Lua behaviours at low tick rates; sidearm, stun, flares,
  decoys, pulses, shields; fire that spreads through dry vegetation, smoke, explosions, lava and
  toxic-gas volumes as visible hazards.
- **Game tests:** without a filter in a toxic biome the Commander dies and wakes in the clone bay
  (Clone mode), or the run ends and the codex carries over (Legacy mode); a predator pack is avoided
  by passive stealth; decoys draw a predator away.

### M11 — Civilisations and villains (XL)

- **OpenSpec:** `add-factions`, `add-native-settlements`, `add-artifact-sites`,
  `add-thieves-and-boarding`, `add-dialogue`.
- **Work:** faction model and reputation, settlements (animated natives, procedural buildings), dialogue
  trees in Lua, ruins with puzzles and defences, thieves who steal unattended dolls, boarding parties
  that path through interiors, tyrant story arcs, rival spacefarers.
- **Game tests:** thieves take an unattended Land Explorer, which can then be tracked and recovered;
  a boarding party reaches the cargo deck unless the sectors are sealed.

### M12 — Progression and economy (L)

- **OpenSpec:** `add-research`, `add-trading`, `add-crafting`, `add-outposts`, `add-codex`.
- **Work:** samples and the research tree, upgrades and doll modules, markets with supply, demand and
  reputation pricing, currencies, crafting recipes, outpost building (power, storage, pads,
  scanners), the codex with naming, exotic matter and jump range.
- **Game tests:** a sample → research → sensor upgrade loop; buy low and sell high between two
  markets; build an outpost, leave and come back to find it unchanged.

### M13 — Story threads, content and polish (L)

- **OpenSpec:** `add-story-threads`, `add-accessibility`, plus content changes.
- **Work:** the mystery arc framework and its first threads; at least 40 marvels; an audio pass with
  ElevenLabs (all dolls, hazards, music layers); a visual pass (materials, lighting and colour grading
  per archetype, effect polish) and a final juice pass over every interaction; a style guide; art
  replacement documentation;
  `docs/MODDING.md` and an example mod; balancing; accessibility (remapping, subtitles for the ship AI,
  colour-blind palette option, motion comfort); text kept in string tables for later translation.

### M14 — Release 1.0 (M)

- Performance pass on the target devices, save compatibility tests, release packaging, a press kit
  page on Pages.

### After 1.0

- **Co-op:** network transport for the command stream (WebSocket or WebRTC on the web), with each
  player in a different doll. The simulation is ready for it from M1.

---

## 7. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Seamless planets with seven scales on mobile WebGL | frame rate, memory | low internal resolution, aggressive LOD, time-sliced generation, per-device quality presets, budgets checked in CI |
| Modern rendering on WebGL 2 (no compute shaders; float targets not everywhere) | missing effects on some devices | fragment-shader and transform-feedback techniques only; LDR fallback; quality presets tested in the browser job |
| Detailed geometry shimmers at low resolution | ugly, tiring image | supersampling or TAA, texel-snapped shadows, LOD by internal pixels, specular anti-aliasing |
| Vertex and draw-call cost does not shrink with resolution | CPU/GPU bound on phones | LOD by internal pixels, instancing, impostors, culling per depth slice |
| Detailed art for a procedural universe | too much hand work | procedural hulls, creatures and materials; CC0 material and sky libraries; glTF pipeline for hand-made models |
| In-house physics in C | bugs, instability | narrow scope (characters, vehicles, debris, ragdolls), determinism tests, no general stacking promises |
| Volumetrics on llvmpipe in CI | slow or flaky tests | fixed `ci` preset, small showcase scenes, reprojection reset per scenario |
| 95% coverage of graphics and platform code | blocked merges | thin `platform/` layer, rendering logic kept separate from GL calls, game tests counted in coverage, llvmpipe in CI |
| Floating-point differences between platforms | different universes on web and desktop | `-ffp-contract=off`, in-house transcendentals, integer hashing, a CI determinism matrix |
| Scope: economy, outposts, deformation, factions, story | never finishing | vertical slice first (M6); each system starts minimal and data-driven; ponytail rules |
| No wasm threads on GitHub Pages | slower generation on the web | single-thread fallback; add `coi-serviceworker` later only if profiling shows a need |
| WebXR through Emscripten | missing bindings | a small custom JS library; mocked tests; the flat mode always works |
| ElevenLabs licence vs CC BY 4.0 | generated sound effects may not be offered standalone | generated audio is excluded from CC BY 4.0 and ships only as part of the game (`LICENSE-ASSETS.md`); provenance is recorded; files can be regenerated or replaced |
| Push-to-main without review | broken `main` | full local test run before push; Pages deploys only green builds; small commits |
| Lua performance | stutter | Lua for decisions only; hot loops in C; per-tick Lua budgets measured in game tests |

---

## 8. Needed from the Project Owner

1. **Enable GitHub Pages** once: *Settings → Pages → Source: GitHub Actions* (done).
2. **ElevenLabs:** the API key is provided (a network secret of the "fukuruma" cloud environment, which also
   allows `api.elevenlabs.io`). ElevenLabs' terms allow generated sound effects only combined with other material
   (no standalone distribution, sublicensing or sound libraries), so generated audio is excluded from CC BY 4.0
   and ships only as part of the game (`LICENSE-ASSETS.md`). The owner's plan is a paid one (commercial use allowed); the music has its
   own [Music Terms](https://elevenlabs.io/music-terms).
3. Optional: install ponytail in your local Claude Code with `/plugin marketplace add DietrichGebert/ponytail`
   and then `/plugin install ponytail@ponytail` (two separate prompts). The repository already contains its `AGENTS.md`.
4. Optional: name the phone and VR headset you want the game tuned for.
