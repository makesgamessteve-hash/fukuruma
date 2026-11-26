# Tasks

## 1. Pure C foundations

- [x] 1.1 `core/mat4.c`: multiply, inverse, orthographic, look-along, point transform
- [x] 1.2 `gfx/shadow.c`: cascade splits, frustum slices, bounding spheres, texel snapping
- [x] 1.3 `gfx/frame.c`: per-frame recording (draws, overlay, camera, sun, ambient, point lights, grading), settings validation
- [x] 1.4 Normal computation for meshes without normals

## 2. GL pipeline

- [x] 2.1 Shader variants with defines; GL loader additions
- [x] 2.2 Targets: G-buffer, lighting, SSAO, bloom chain, luminance, exposure, final image; LDR fallback
- [x] 2.3 Passes: shadows, G-buffer, SSAO, lighting, bloom, exposure, post, supersample filter, overlay, upscale
- [x] 2.4 Shaders in `data/shaders/`

## 3. Scripts and engine

- [x] 3.1 `fk.gfx` API: `mesh` (normals), `draw`, `overlay`, `camera`, `sun`, `ambient`, `light`, `clear`, `grade`, `configure`, `settings`
- [x] 3.2 Input positions relative to the image
- [x] 3.3 App: render after `draw`, screenshots from the internal image
- [x] 3.4 Lit stage in `main.lua`, `shapes.lua`; touch controls as overlay

## 4. Tests

- [x] 4.1 C unit tests: mat4, cascades and snapping, frame recording and validation, upscale rectangle
- [x] 4.2 Lua tests for the new `fk.gfx` API (validation without a window)
- [x] 4.3 `tests/game/showcase_lighting.lua` with golden images (HDR, supersampled, LDR); regenerate `boot` and `input`
- [x] 4.4 Browser tests still pass (WebGL 2 path)

## 5. Verification

- [x] 5.1 Coverage gates, sanitizers, all CTest tests
- [x] 5.2 CI green on every target; Pages updated
- [x] 5.3 `openspec validate add-render-pipeline --strict`; update the plan (moved items); archive after deployment
