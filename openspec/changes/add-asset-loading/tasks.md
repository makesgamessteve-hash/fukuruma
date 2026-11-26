# Tasks

## 1. Engine (C)

- [x] 1.1 Vendor cgltf 1.15 and stb_vorbis; JPEG in stb_image; notices
- [x] 1.2 `fk_vertex` layout, texture upload with mipmaps, material textures in the G-buffer pass, normal maps
- [x] 1.3 `assets/image.c`, `assets/model.c` (meshes, materials, images, nodes, skins, clips; paths inside data/)
- [x] 1.4 `assets/sound.c` (WAV via SDL, OGG via stb_vorbis, 48 kHz float, length check first)
- [x] 1.5 `assets/watch.c` and hot reload in the app (shaders, scripts, textures, models)
- [x] 1.6 `fk.gfx.texture`, `fk.gfx.model`, `model:clips()`, `model:nodes()`, mesh UVs, draw with texture or model
- [x] 1.7 `require("game")`

## 2. Content

- [x] 2.1 `tools/models/gltf.py` and `make_models.py`: Exosuit, materials showcase, test ground; CREDITS.md
- [x] 2.2 `tools/models/make_fixtures.py`: test models, images and sounds, including broken ones

## 3. Tests

- [x] 3.1 C unit tests: images, models (files, data URIs, matrices, skins, clips, failures), sounds, watcher, reloads, tangents
- [x] 3.2 Lua tests: textures, models, path checks, tiled planes
- [x] 3.3 `tests/game/showcase_materials.lua` with a golden image
- [x] 3.4 Hot reload tried by hand in a window (shader, script, broken script, fixed script)

## 4. Verification

- [x] 4.1 Coverage gates, sanitizers, all CTest tests, web build and browser tests
- [ ] 4.2 CI green on every target; Pages updated
- [ ] 4.3 `openspec validate add-asset-loading --strict`; archive after deployment
