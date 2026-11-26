# Design

## Context

The repository holds only `LICENSE`, the concept and the plan. This change creates the build, the
smallest engine that proves the C ↔ Lua ↔ OpenGL path on five targets, the test tooling every later
change relies on, and the CI that publishes to GitHub Pages. See `docs/IMPLEMENTATION_PLAN.md` §1–§5
for the overall stack.

## Goals / Non-Goals

**Goals:**
- One CMake build for Linux, Windows, macOS and Web, with presets.
- A window with a GL context and a spinning placeholder drawn from Lua.
- `data/` resolved beside the executable; nothing from `data/` compiled in.
- Headless rendering on Linux CI; `--no-render` on Windows and macOS CI.
- C unit tests, Lua unit tests, scenarios with golden images, coverage gates.
- Green CI deploys the web build to Pages.

**Non-Goals:**
- The fixed-tick simulation, commands and entities (M1). M0 uses a plain per-frame `update(dt)`;
  in scenarios `dt` is fixed at 1/60 s.
- Input mapping, retro post-processing, asset loaders other than Lua and GLSL, audio, touch, WebXR,
  mod loading.

## Decisions

### SDL3 main callbacks for the loop
Use `SDL_MAIN_USE_CALLBACKS` (`SDL_AppInit`, `SDL_AppIterate`, `SDL_AppEvent`, `SDL_AppQuit`). SDL
drives the loop on every platform, including Emscripten, so there is no `#ifdef __EMSCRIPTEN__` loop
code. Alternative: a `while` loop plus `emscripten_set_main_loop`, which needs two code paths.

### Dependencies
- **SDL 3.4.20** through CMake `FetchContent` from the release tarball with a pinned SHA-256, built
  static. It is large, so it is not vendored. On the web it is built from the same source with the
  Emscripten toolchain file. Our strict C11 settings are applied after SDL is added, because SDL needs
  GNU extensions for `EM_ASM` on the web.
- **Lua 5.4.x**, **utest.h**, **stb_image** and **stb_image_write** (golden image read and write) and
  **luacov** are vendored in `third_party/` because they are small and must not change underneath us.

### GL function loading
One X-macro list in `gfx/gl_gfx.c` names the GL functions the engine uses, with their signatures.
They are loaded through the platform's `SDL_GL_GetProcAddress` on every target (on the web with
`-sGL_ENABLE_GET_PROC_ADDRESS`). There is no generated loader.

### Shaders
GLSL files in `data/shaders/` are written without a `#version` line. The engine prepends
`#version 330 core` on desktop or `#version 300 es` with `precision highp float;` on the web.

### Paths
`SDL_GetBasePath()` + `data/`. On the web, Emscripten's `--preload-file data@/data` produces
`fukuruma.data` beside `fukuruma.wasm`, and the base path is `/`.

### Lua sandbox
Game scripts never run in the global table. Every chunk gets a separate environment table (`_ENV`)
holding only safe base functions, `coroutine`, `string`, `table`, `utf8`, a copy of `math` without
`random`/`randomseed` (randomness will come from seeded streams), `print` (to the log), `require` and
`fk`. There is no `load`, `dofile`, `loadfile`, `io`, `os`, `debug` or `package`. `require` accepts
only module names of letters, digits, `_` and single dots and reads `data/scripts/<a/b>.lua` through
the engine. In `--test --coverage` runs the host globals also get the standard libraries for luacov;
the sandbox is unchanged.

### Headless rendering
- Linux CI: `--headless` selects SDL's `offscreen` video driver, which creates the GL context through
  EGL on Mesa **llvmpipe** (packages `libegl1 libegl-mesa0 libgl1-mesa-dri`). No X server is needed.
- Windows and macOS CI: `--no-render`, because their runners have no dependable GPU.
- Golden images are 480×270 PNGs. The comparison counts pixels whose channels differ by more than
  8/255; more than 0.5% such pixels fails. Every screenshot is also written to `test-output/<name>.png`
  (a CI artifact), which the reproducibility test compares byte for byte.
- In the browser, screenshot steps are skipped and logged: browser GPUs do not match llvmpipe.

### Scenario runner
A scenario file returns `scenario { seed, timeout_s, run = function(t) ... end }`. `run` executes in
a coroutine: `t.frames(n)` and `t.screenshot(name)` yield to the engine, which advances frames at a
fixed 1/60 s; `t.expect(cond, msg)` raises an error with the caller's file and line. `--seed` on the
command line wins over the scenario's seed. The same runner is used in the browser through
`?scenario=`; the result is written to `window.fukurumaResult`. Timeouts exit with code 2, which SDL's
callbacks cannot express, so `SDL_AppQuit` calls `exit(2)` itself.

### Coverage
- C: a `linux-coverage` preset builds with `--coverage`; gcovr runs over `engine/src` after unit tests
  and scenarios and fails under 95% line coverage.
- Lua: `--test --coverage` loads luacov; a small report step fails under 95% for `data/scripts`.

### CI and Pages
One workflow, `.github/workflows/ci.yml`, jobs as in the plan §5. The `pages` job needs all others,
runs only on `main`, uses `actions/configure-pages`, `actions/upload-pages-artifact` and
`actions/deploy-pages`, with `permissions: pages: write, id-token: write` and a `pages` concurrency
group. Emscripten is installed from the official `emsdk` repository at a pinned version.

## Risks / Trade-offs

- **llvmpipe output changes with Mesa versions** → pin the runner image (`ubuntu-24.04`), keep the
  tolerance, regenerate golden images on purpose with `--update-golden`.
- **Error paths that need a broken GPU driver** (context creation, shader linking) cannot be triggered
  in CI; they stay uncovered within the 5% allowance.
- **95% coverage of `platform/`** → keep it thin; it runs in every headless scenario on Linux.
- **GitHub Pages must be enabled by hand** → the `pages` job fails with a clear message until the
  owner enables it; the README states the one-time step.
