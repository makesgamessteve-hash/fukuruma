# Tasks

## 1. Repository and licences

- [x] 1.1 Create the folder layout from `docs/IMPLEMENTATION_PLAN.md` §2 (`engine/`, `data/`, `mods/`, `tests/`, `tools/`, `third_party/`, `web/`, `.github/workflows/`)
- [x] 1.2 Add an entry to `THIRD_PARTY_NOTICES.md` for every vendored or fetched library (SDL3, Lua, utest.h, stb, luacov)
- [x] 1.3 Add `.gitignore` (build folders, test output, coverage reports, `node_modules/`)
- [x] 1.4 Extend `README.md`: build instructions, folder overview, licences, the one-time Pages setup step

## 2. Build system

- [x] 2.1 Root `CMakeLists.txt` (C11, warnings as errors in CI, `-ffp-contract=off`) that copies `data/` beside the built executable
- [x] 2.2 `FetchContent` for SDL 3.4.20 (pinned tarball hash, static); vendor Lua 5.4.9, utest.h, stb_image, stb_image_write, luacov in `third_party/`
- [x] 2.3 `CMakePresets.json`: `linux-debug`, `linux-coverage`, `linux-asan`, `windows-msvc`, `macos`, `web`
- [x] 2.4 Emscripten settings: WebGL 2 only, memory growth, `--preload-file data@/data`, `web/shell.html`

## 3. Engine skeleton

- [x] 3.1 `app/`: SDL main callbacks, CLI parsing (`--headless`, `--no-render`, `--test`, `--scenario`, `--seed`, `--update-golden`)
- [x] 3.2 `platform/`: window and GL 3.3 core / GLES 3.0 context creation, offscreen mode, base path
- [x] 3.3 `gfx/`: GL X-macro loader, shader loading with `#version` injection, mesh upload and draw, clear, frame read-back
- [x] 3.4 `assets/`: data path resolution and file reading; error with the searched path when `main.lua` is missing
- [x] 3.5 `script/`: sandboxed Lua state, data-folder `require` searcher, `fk.gfx.clear`, `fk.gfx.mesh`, `fk.gfx.draw`, `fk.seed`, error reporting with traceback and on-screen message
- [x] 3.6 `data/scripts/main.lua` and `data/shaders/flat.glsl`: the spinning low-poly placeholder (a Jump Ship silhouette)

## 4. Test harness

- [x] 4.1 C unit tests with utest.h registered in CTest (`tests/unit/`)
- [x] 4.2 Lua test runner for `--test` (`*_test.lua` discovery, per-test result lines, exit code)
- [x] 4.3 Scenario runner (coroutine helpers `frames`, `expect`, `screenshot`, fixed 1/60 s step, exit codes 0/1/2)
- [x] 4.4 Golden image compare and diff output; `--update-golden`
- [x] 4.5 `tests/game/boot.lua` and `tests/golden/boot.png`
- [x] 4.6 Coverage: gcovr target with `--fail-under-line 95` for `engine/src`; luacov report with a 95% gate for `data/scripts`

## 5. Web build

- [x] 5.1 `web/shell.html`: full-window canvas, loading progress, WebGL 2 check with a readable message
- [x] 5.2 `?scenario=` support and `window.fukurumaResult`
- [x] 5.3 Browser tests in `tests/web/smoke.mjs` (Playwright library): page renders a non-blank canvas; `?scenario=boot` passes; the unsupported-browser message appears when WebGL 2 is disabled

## 6. CI and Pages

- [x] 6.1 `.github/workflows/ci.yml` with the jobs `specs`, `linux`, `sanitize`, `windows`, `macos`, `web`, `pages`
- [x] 6.2 Upload golden-image diffs and coverage reports as artifacts on failure
- [ ] 6.3 Confirm the owner has enabled Pages (Source: GitHub Actions) and the site is reachable

## 7. Verification

- [x] 7.1 All C and Lua unit tests pass; both coverage gates are at or above 95%
- [x] 7.2 `boot.lua` passes headless on Linux, with `--no-render` on Windows and macOS, and in Chromium on the web
- [ ] 7.3 CI is green on every target and the placeholder is live at https://makesgamessteve-hash.github.io/fukuruma/
- [ ] 7.4 `openspec validate add-project-foundation --strict` passes; archive the change after deployment
