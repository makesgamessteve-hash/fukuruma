# Tasks

## 1. Engine (C)

- [x] 1.1 Sprite batch: `fk.gfx.text` and `fk.gfx.rect`, font atlas loading, shader `sprite.glsl`
- [x] 1.2 TAA: Halton jitter, resolve pass (`taa.glsl`), history targets, settings field `taa`
- [x] 1.3 Palette mode in `post.glsl`, `fk.gfx.palette`
- [x] 1.4 Fill the window: settings field `fill`, internal size computed at render time, `fk.gfx.size`
- [x] 1.5 `fk.gfx.device()` (renderer, software, browser, phone)
- [x] 1.6 `fk.storage` with files, IndexedDB on the web, memory for test runs

## 2. Game (Lua)

- [x] 2.1 `fk/ui.lua`: rows, focus, wrapping, option values, keyboard / gamepad / mouse / touch
- [x] 2.2 `settings/graphics.lua`: levels, Custom, apply, device defaults, save and load
- [x] 2.3 `menu.lua` and `main.lua`: open/close, touch menu button, game input paused while open

## 3. Tests

- [x] 3.1 C unit tests: Halton jitter, fill size, storage names and memory mode, text quads
- [x] 3.2 Lua tests: levels and Custom, settings round trip, device defaults, UI navigation
- [x] 3.3 `tests/game/graphics_menu.lua` with a golden image per level, palette and fill; TAA image in the showcase
- [x] 3.4 Browser: the menu opens with a tap and stored settings survive a reload
- [x] 3.5 Found by the browser test: quick presses (down and up between two frames) last one frame; the web
  canvas covers the page; the renderer leaves no framebuffer bound, so Chrome keeps showing the canvas after
  a reconfiguration

## 4. Verification

- [x] 4.1 Coverage gates, sanitizers, all CTest tests
- [x] 4.2 CI green on every target; Pages updated
- [x] 4.3 `openspec validate add-graphics-settings --strict`; archive after deployment
