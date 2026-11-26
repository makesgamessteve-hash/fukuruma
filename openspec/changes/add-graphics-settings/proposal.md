# Proposal

## Why

The owner asked for graphics detail levels that differ mostly in light, shadows and effects and only
a little in models, switchable in an in-game menu (`docs/CONCEPT.md` §6.2). The render pipeline from
`add-render-pipeline` can be configured, but nothing chooses or saves a configuration, there is no
text or menu, temporal anti-aliasing and the palette mode are still missing, and phones show black
bars because the internal image is always 16:9.

## What Changes

- **Detail levels** Low, Medium, High, Ultra and Custom, defined in Lua (`data/scripts/settings/graphics.lua`).
  They vary shadows, ambient occlusion, point lights and anti-aliasing (none, temporal, 2×2 supersampling);
  rows for clouds, fog, water and particles are added as those features arrive.
- **In-game menu** *Settings → Graphics* (Escape, the gamepad's Start button or a touch button): detail
  level, resolution (Classic, Sharp, Fine), fill the window, anti-aliasing, dithering, palette mode,
  and the Custom rows. Changes apply immediately while the scene keeps running behind the menu.
  Keyboard, gamepad, mouse and touch all work.
- **Text and UI**: an 8×8 pixel font (public domain) and filled rectangles drawn on the internal image;
  a small immediate-mode UI module in Lua (`fk.ui`).
- **Temporal anti-aliasing**: sub-pixel jitter, reprojection of the previous frame and neighbourhood clamping.
- **Palette mode**: the image is quantised to a palette with ordered dithering (the strong retro look).
- **Fill the window**: the internal image takes the window's shape (for example 585×270 on a 2340×1080
  phone) so there are no bars, still at a whole-number scale.
- **Device defaults**: the first start picks a level from the device (software renderer or phone → Low,
  browser on a desktop → Medium, otherwise High).
- **Saved settings**: scripts can store small text values (`fk.storage`); on the web they survive
  reloads (IndexedDB). Test runs use memory only, so they cannot affect each other.

**Out of scope:** a full options screen (audio, controls; they come with their changes), localisation,
per-world palettes (M4 generates them), level-of-detail for models (no LOD system yet; the detail
levels gain a model-LOD row when it exists).

**Proving game tests:** `tests/game/graphics_menu.lua` opens the menu with emulated input, switches
through all four levels, compares a golden image per level, toggles palette mode and fill, and checks
that the settings are stored. `tests/game/showcase_lighting.lua` gains a TAA image.

## Capabilities

### New Capabilities

- `graphics-settings`: detail levels, the graphics menu, device defaults and saved settings.
- `ui`: pixel text, rectangles and menu navigation with every input device.
- `storage`: small persistent text values for scripts.

### Modified Capabilities

- `rendering`: temporal anti-aliasing, palette mode and filling the window; the upscale requirement
  covers the window-shaped internal image.

## Impact

- `engine/src/gfx/gl_pipeline.c` (TAA, palette, fill, text batch), `gfx/frame.c`, `script/lua_gfx.c`,
  new `script/lua_storage.c`, `platform` (storage files, IndexedDB on the web, device info).
- New shaders `taa.glsl`, `sprite.glsl`; `post.glsl` gains the palette.
- New `data/fonts/font8x8.png`, `data/scripts/fk/ui.lua`, `data/scripts/settings/graphics.lua`,
  `data/scripts/menu.lua`; `main.lua` opens the menu.
