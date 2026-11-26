# Fukuruma — Implementation Plan

> Status: **v1.0**, 2026-11-26. Based on [CONCEPT.md](CONCEPT.md) v0.2.
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
| Platform | SDL 3.2.x, pinned tag, built from source (static) | zlib | Window, GL context, input (keyboard, mouse, gamepad, touch), audio, threads, paths. |
| Graphics | OpenGL 3.3 core / OpenGL ES 3.0 / WebGL 2 common subset | — | Runs on Windows, Linux, macOS (4.1 core) and browsers. |
| GL loading | `SDL_GL_GetProcAddress` + one X-macro list of the functions used | — | No generator, no extra dependency. |
| Scripting | Lua 5.4.x, vendored source | MIT | Small, portable, works on WebAssembly (LuaJIT does not). |
| Images | stb_image | PD / MIT | PNG textures, palettes, sprite sheets. |
| Audio decode | stb_vorbis (OGG); WAV through SDL | PD / MIT | OGG loops seamlessly (MP3 adds gaps). |
| Models | cgltf (glTF 2.0 / .glb) | MIT | Blender exports it; good for modders. |
| Voxels | ogt_vox (MagicaVoxel .vox) | MIT / PD | The standard voxel art tool. |
| Noise | FastNoiseLite (C99 header) | MIT | Simplex, cellular, fractal and domain warp in one header. |
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
  include/fk/              public headers: fk_core.h, fk_math.h, fk_gfx.h, fk_world.h, ...
  src/
    app/                   main(), CLI (--headless, --test, --scenario, --seed, --no-render)
    core/                  log, arenas, hash + PRNG, jobs, time, commands, entities
    platform/              SDL3 glue: window, GL context, input events, audio device, paths
    gfx/                   GL wrapper, retro pipeline, meshes, sprites, text, UI drawing
    audio/                 mixer, 3D panning, music layers, decoders
    assets/                VFS (data/ + mods/), loaders (png, gltf, vox, ogg, wav), hot reload
    script/                Lua state, fk.* bindings, sandbox, registries
    world/                 reference frames, orbits, collision, save/load
    gen/                   noise graphs, galaxy, systems, planet fields, terrain chunks,
                           voxels, interiors, creature voxels
data/                      shipped beside the binary
  scripts/                 Lua game (MIT): main.lua, dolls/, gen/, marvels/, ecology/,
                           factions/, economy/, research/, story/, ui/, input/
  shaders/                 GLSL (MIT)
  palettes/ textures/ models/ voxels/ sprites/ fonts/ sounds/ music/   (CC BY 4.0)
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
third_party/               lua, stb, cgltf, ogt_vox, FastNoiseLite, utest, luacov
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
            │ world/  gen/  gfx/  audio/  assets/  (testable logic) │
            │ core/   (hash, PRNG, jobs, commands, entities, log)   │
            └───────────────▲──────────────────────────────────────┘
                            │ the only layer that calls SDL directly
            ┌───────────────┴──────────────────────────────────────┐
            │ platform/  (SDL3 window, events, audio device, paths) │
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

### 3.4 Retro rendering pipeline

1. Skybox cube map, baked once per system: real neighbouring stars, nebulae, the galactic band.
2. Celestial slice: stars (corona billboards), distant planets in scaled space, the Jump Ship and stations.
3. Planetary slice: the cube-sphere planet with LOD, the atmosphere shell, clouds, rings, eclipses.
4. Local slice: terrain chunks, voxel meshes, glTF models, 8-direction sprites, particles.
5. All slices render into a **low-resolution target** (default 480×270).
6. Post pass: the per-world **palette lookup + ordered dithering**, fog bands, optional subtle
   vertex snap, then an integer nearest-neighbour upscale to the window.
7. UI pass: bitmap-font text and immediate-mode widgets, drawn diegetically where possible (the
   visor HUD, cockpit screens).

Shaders live in `data/shaders/*.glsl`. The engine adds the right `#version` line and precision
qualifiers for desktop GL 3.3 or GLES 3.0. In VR, each eye is rendered into the XR framebuffer with
the same pipeline, at a higher internal resolution.

### 3.5 Procedural generation

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

### 3.6 Interiors

- Hull: a Lua definition that names a model, a bounding volume and a zone list.
- Zones are placed in the hull volume by a grammar (Lua). Each zone fills **sectors** (fixed cubes,
  for example 64 m). Each sector is a tile grid (2 m cells, 6 m clear height for the Exosuit) filled
  with kit pieces: rooms, corridors, shafts, hangar walls.
- Sectors are generated by jobs when the Commander comes within N sectors, and unloaded beyond N+2.
- Hand-authored rooms (bridge, clone bay, research deck) are Lua/voxel files that override the grammar.
- Transit: lifts, trams on zone spines, teleport pads. Hangars show the docked child dolls at full scale.

### 3.7 The Lua layer

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

### 3.8 Assets, mods and saves

- **VFS:** the search order is `mods/<load order>/` → `data/`. Paths are resolved with `SDL_GetBasePath()`.
  On the web, `data/` is packaged by Emscripten as `fukuruma.data` next to `fukuruma.wasm`.
- **Mods:** `mods/<name>/mod.lua` holds the name, version, load order and dependencies. A mod can
  add or replace files and register new content.
- **Saves:** the world seed plus all deltas (chunk edits, interior sectors, entities, factions,
  economy, codex), written as versioned Lua-table text. They are stored in `SDL_GetPrefPath()`, and
  on the web in IndexedDB (IDBFS).

### 3.9 Audio

- A mixer on SDL3 audio streams: one-shot and looping sources, 3D panning and attenuation,
  per-category volumes, and music **layers** that crossfade by situation (deep space, orbit,
  surface, danger, discovery).
- `tools/audio/generate.py` reads `tools/audio/prompts.json` (ID, sound effect or music, prompt,
  length, loop flag, target path). It calls ElevenLabs only for entries whose prompt hash changed,
  converts the result to OGG Vorbis with ffmpeg, and records provenance in `data/sounds/CREDITS.md`
  and `data/music/CREDITS.md`.
- Facts from ElevenLabs' public docs (to be re-checked when the tool is written): sound effects
  are 0.5–30 s, with a `loop` option on the v2 model; music is 3 s to 10 min.

### 3.10 Input and platforms

- **Action maps** in Lua (`data/scripts/input/*.lua`): actions such as `move`, `look`, `deploy`,
  `scan`, `board`, bound per device and per doll. Players can remap them.
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
| Visual | golden screenshots (480×270, palette-quantized) | built into the scenario runner | ≤ 0.5% pixels differ |
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

### M0 — Foundation and pipeline (M)

- **OpenSpec:** `add-project-foundation` (written; see `openspec/changes/add-project-foundation/`).
- **Capabilities:** `asset-layout`, `script-runtime`, `test-harness`, `web-distribution`.
- **Work:** repository layout, licences, README, AGENTS.md and CLAUDE.md; CMake presets for five
  targets; SDL3 window and GL context; GL loader; Lua VM running `data/scripts/main.lua`, which draws a
  spinning low-poly placeholder through `fk.gfx`; minimal VFS; CLI (`--headless`, `--test`,
  `--scenario`, `--seed`, `--no-render`); utest, luacov and gcovr gates; the CI workflow; Pages
  deployment; Playwright smoke test.
- **Game test:** `boot.lua`: start, render 120 frames, match the golden image, exit 0.
- **Exit:** Pages shows the placeholder; CI is green on all targets; coverage ≥ 95%.

### M1 — Engine core (L)

- **OpenSpec:** `add-simulation-loop` (fixed tick, commands, entities, named RNG streams, jobs),
  `add-input-actions` (action maps, keyboard, mouse, gamepad, touch detection and a basic virtual
  stick), `add-retro-renderer` (shaders, meshes, textures, low-res target, palette and dither,
  sprites, bitmap text, immediate UI, screenshots), `add-asset-loading` (PNG, glTF, VOX with greedy
  meshing, OGG, WAV, hot reload), `add-audio` (mixer, 3D, music layers, the ElevenLabs tool and a
  first set of sounds), `add-save-system` (snapshot and deltas, IDBFS, versioning).
- **Game test:** a sandbox scene: a placeholder Exosuit walks on a plane with keyboard input and
  with emulated touch input, and a save/load round-trip keeps its position.
- **Exit:** the sandbox is playable on desktop and phone browsers, with sound.

### M2 — Reference frames and scale (M)

- **OpenSpec:** `add-reference-frames`, `add-orbital-mechanics`, `add-collision`.
- **Work:** the frame tree, double positions, camera-relative transforms, depth slices, scaled space,
  frame transitions, Kepler orbits, character controller, gravity per body.
- **Game test:** the *scale ladder*: the camera moves from a 1 m cube to a 144 km hull to a planet to
  a star. A golden image at each step; position jitter < 1 mm at 100 AU from the star.

### M3 — Galaxy and star systems (L)

- **OpenSpec:** `add-galaxy-generation`, `add-star-systems`, `add-wonder-director`, `add-navigation-maps`.
- **Work:** hash and PRNG hierarchy, galaxy density and sector stars, star physics, the eleven system
  archetypes, orbits, moons, rings, belts and comets, Lua archetype registry, the Wonder Director
  with at least 10 marvels, galaxy and system maps, skybox baking, the jump sequence.
- **Tests:** statistical unit tests over 10,000 systems (no unstable orbits; at least one marvel per
  system; target rarity ±20%); determinism hashes on all platforms; a game test that jumps through
  three systems.

### M4 — Planets from space (L)

- **OpenSpec:** `add-noise-graphs`, `add-planet-descriptors`, `add-planet-rendering`, `add-star-rendering`.
- **Work:** the noise-graph DSL and evaluator, global fields (plates, elevation, climate, biomes),
  baked planet textures, cube-sphere LOD, atmosphere, clouds, night lights, rings with shadows,
  eclipses, per-world palettes, star coronas, binary lighting, the first marvel visuals (polar ring,
  black hole lensing, pulsar beam).
- **Game test:** orbit one planet of each archetype; golden images; draw-call and triangle budgets.

### M5 — Seamless surfaces (XL)

- **OpenSpec:** `add-terrain-streaming`, `add-biomes-and-scatter`, `add-voxel-terrain`, `add-weather`.
- **Work:** quadtree chunk streaming from orbit to the ground without cracks, regional detail,
  rivers, lakes and oceans, biome scatter (sprite flora, rocks), voxel near field (surface nets,
  flat shading), **terrain deformation** with persistent deltas, terrain collision, day and night,
  weather, time-sliced generation on the web.
- **Game tests:** a descent from station orbit to the ground in one continuous flight (no holes, within
  budget); dig a tunnel, save, reload and walk through it; chunk determinism hashes.

### M6 — The Fukuruma chain: vertical slice (XL)

- **OpenSpec:** `add-doll-chain`, `add-vehicle-controllers`, `add-teleport-network`, `add-autopilot`.
- **Work:** the doll registry and schema, placeholder hulls for the seven dolls and the Drop Ship,
  deploy / recall / board / disembark, one controller per doll (jump drive, orbit, flight, crawl,
  legs with simple IK, first-person Exosuit), the teleport network, cockpits and cameras, autopilot
  with time compression, ship-AI text lines.
- **Game test:** *the Fukuruma test*: the whole chain down and back up (see §4). It runs on every push
  from now on.
- **Exit:** the vertical slice is playable on Pages: one system, one planet, every doll.

### M7 — Touch and WebXR (L)

- **OpenSpec:** `add-touch-controls`, `add-webxr`.
- **Work:** a touch layout per doll, UI scaling, the WebXR session, stereo rendering, controller
  mapping, comfort options, the visor HUD, cockpits in VR, performance tuning for Quest-class devices.
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
  map and HUD overlays, autopilot hazard stops, the visor HUD.
- **Game tests:** a hazard below the Walker's resolution is invisible to the Walker and visible to the
  Exosuit; an active ping alerts a hostile; autopilot stops at a detected sinkhole.

### M10 — Hazards, survival and life (XL)

- **OpenSpec:** `add-environment-model`, `add-exosuit-survival`, `add-death-modes`, `add-ecology`,
  `add-creature-generation`, `add-defensive-tools`.
- **Work:** atmosphere, pressure, temperature, radiation and toxins; terrain hazards; Exosuit systems
  and doll damage; Clone mode and Legacy mode; procedural flora and fauna (body-plan grammar →
  voxel model → 8-direction sprite sheet); ecology tables per biome; Lua behaviours at low tick rates;
  sidearm, stun, flares, decoys, pulses, shields.
- **Game tests:** without a filter in a toxic biome the Commander dies and wakes in the clone bay
  (Clone mode), or the run ends and the codex carries over (Legacy mode); a predator pack is avoided
  by passive stealth; decoys draw a predator away.

### M11 — Civilisations and villains (XL)

- **OpenSpec:** `add-factions`, `add-native-settlements`, `add-artifact-sites`,
  `add-thieves-and-boarding`, `add-dialogue`.
- **Work:** faction model and reputation, settlements (sprite people, voxel buildings), dialogue
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
  ElevenLabs (all dolls, hazards, music layers); a style guide; art replacement documentation;
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
| 95% coverage of graphics and platform code | blocked merges | thin `platform/` layer, rendering logic kept separate from GL calls, game tests counted in coverage, llvmpipe in CI |
| Floating-point differences between platforms | different universes on web and desktop | `-ffp-contract=off`, in-house transcendentals, integer hashing, a CI determinism matrix |
| Scope: economy, outposts, deformation, factions, story | never finishing | vertical slice first (M6); each system starts minimal and data-driven; ponytail rules |
| No wasm threads on GitHub Pages | slower generation on the web | single-thread fallback; add `coi-serviceworker` later only if profiling shows a need |
| WebXR through Emscripten | missing bindings | a small custom JS library; mocked tests; the flat mode always works |
| ElevenLabs licence vs CC BY 4.0 | audio cannot be redistributed | the owner confirms their plan's terms before generated audio is committed; provenance is recorded; files can be regenerated or replaced |
| Push-to-main without review | broken `main` | full local test run before push; Pages deploys only green builds; small commits |
| Lua performance | stutter | Lua for decisions only; hot loops in C; per-tick Lua budgets measured in game tests |

---

## 8. Needed from the Project Owner

1. **Enable GitHub Pages** once: *Settings → Pages → Source: GitHub Actions*.
2. **ElevenLabs:** an API key, and confirmation that your plan's terms allow publishing the generated
   sound effects and music under CC BY 4.0 (the public pages say commercial use needs a paid plan,
   and game rights for large studios need Enterprise; the binding text is in the
   [Music Terms](https://elevenlabs.io/music-terms)). In this cloud environment the host
   `api.elevenlabs.io` must also be allowed and the key stored as a network secret. I will request
   both when M1's audio work starts.
3. Optional: install ponytail in your local Claude Code with `/plugin marketplace add DietrichGebert/ponytail`
   and then `/plugin install ponytail@ponytail` (two separate prompts). The repository already contains its `AGENTS.md`.
4. Optional: name the phone and VR headset you want the game tuned for.
