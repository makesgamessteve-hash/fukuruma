# Proposal

## Why

Fukuruma has a concept and a plan but no code. Every later milestone depends on the same base: a
C engine that builds for five targets, loads its game from Lua and assets beside the binary, runs
headless for automated tests, and publishes a web build. Building that pipeline first means every
following change is tested and deployed from its first commit.

## What Changes

- Repository skeleton as laid out in `docs/IMPLEMENTATION_PLAN.md` §2: `engine/`, `data/`, `mods/`,
  `tests/`, `tools/`, `third_party/`, `web/`, `.github/workflows/`.
- Build and contribution notes in `README.md` (the Pages link, `LICENSE`, `LICENSE-ASSETS.md`,
  `AGENTS.md` and `CLAUDE.md` already exist from the planning commit); third-party entries in
  `THIRD_PARTY_NOTICES.md`.
- CMake build with presets for Linux, Windows, macOS, Web and a Linux coverage build; SDL 3.4 and
  Lua 5.4 built from pinned sources.
- A minimal engine: opens a window with an OpenGL context (WebGL 2 on the web), finds `data/` beside
  the binary, runs `data/scripts/main.lua`, which draws a spinning low-poly placeholder through a first
  `fk.gfx` binding.
- Command-line modes: `--headless`, `--no-render`, `--test <dir>`, `--scenario <file>`, `--seed <n>`,
  `--update-golden`.
- Test tooling: C unit tests with CTest, Lua unit tests, the scenario runner with golden screenshots,
  C and Lua coverage gates at 95%.
- One CI workflow: build and test on Linux, Windows, macOS and Web; validate OpenSpec; deploy the web
  build to GitHub Pages when everything passes.

**Out of scope:** gameplay, the fixed-tick simulation, input mapping, the render pipeline (PBR
lighting, shadows, effects, the retro-resolution filter), asset loaders other than Lua scripts and GLSL shaders, audio, touch controls, WebXR, mods
loading beyond the documented folder. These come in M1 and later.

**Proving game test:** `tests/game/boot.lua`: start headless, render 120 frames of the placeholder,
compare the last frame with `tests/golden/boot.png`, exit with code 0.

## Capabilities

### New Capabilities

- `asset-layout`: where the game finds its data (`data/` and `mods/` beside the binary, the packaged
  data file on the web) and how it reports missing data.
- `script-runtime`: how the engine starts the Lua game, what the sandbox allows, and how script errors
  are reported.
- `test-harness`: the headless command-line modes, the scenario runner, golden screenshots and exit codes.
- `web-distribution`: the browser build, its hosting on GitHub Pages from `main`, and what the page
  shows on unsupported browsers.

### Modified Capabilities

None (first change).

## Impact

- New: the entire build system and source tree; third-party sources (SDL3, Lua, utest.h, luacov,
  stb_image and stb_image_write for golden screenshots).
- CI: GitHub Actions minutes on four operating systems; GitHub Pages must be enabled by the owner
  (Source: GitHub Actions).
- No existing code or behaviour is affected.
