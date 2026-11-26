# Design

## Context

`fk.gfx.configure` exists. This change adds what players use: levels, a menu, text, TAA, the palette
mode, a window-filling image, device defaults and stored settings.

## Decisions

### Levels are Lua data
`settings/graphics.lua` maps each level to `fk.gfx.configure` fields and an anti-aliasing mode
(`none`, `taa`, `ssaa`). Low: 1 cascade 1024, no AO, 4 lights, none. Medium: 2 cascades 1024, 6 AO
samples, 8 lights, TAA. High: 3 cascades 2048, 10 samples, 16 lights, TAA. Ultra: 4 cascades 2048,
16 samples, 32 lights, 2×2 supersampling. Changing any Custom row switches the level to Custom and keeps
the rest. The settings are saved as `key=value` lines through `fk.storage` and parsed with string
patterns (the sandbox has no `load`).

### Text and rectangles in one sprite batch
`fk.gfx.text(x, y, string, color)` and `fk.gfx.rect(x, y, w, h, color)` record quads in internal-image
pixels into the frame's overlay list (in order with the overlay meshes). The pipeline builds one vertex
array per frame (position, UV, RGBA), uploads it to a streaming buffer and draws it with alpha blending
from `data/fonts/font8x8.png` (decoded with stb_image). Rectangles use the atlas's solid cell 0.

### TAA
The camera projection is offset by a Halton(2, 3) sequence of 8 sub-pixel jitters (its column 2 for
perspective). G-buffer, SSAO and lighting use the jittered matrices; shadows use the plain ones, so
cascade snapping stays stable. A resolve pass after lighting reprojects each pixel with its depth into
the previous frame (previous un-jittered view-projection), samples the history bilinearly, clamps it to
the 3×3 min/max of the current frame and blends 10% current / 90% history into a ping-pong history
target, which then feeds exposure, bloom and post. History resets on reconfiguration, so scenarios are
reproducible.

### Palette
`fk.gfx.palette(colours)` (up to 64 sRGB colours, `nil` to switch off). The post pass adds a stronger
Bayer offset (±1/8) and picks the nearest palette colour.

### Fill
The configured height is the target; when `fill` is on and the window is at least that tall, the
pipeline computes `scale = floor(window_h / height)` and the internal size `window / scale` at render
time, and recreates the targets when it changes. `fk.gfx.size()` returns the internal size in use.

### Device information
`fk.gfx.device()` returns the GL renderer string, whether it is a software renderer (llvmpipe,
SwiftShader, softpipe, Microsoft Basic Render), whether the game runs in a browser, and whether the
device is a phone or tablet (browser with a coarse pointer). The defaults in the spec are Lua rules
over this table.

### Storage
`fk.storage.save(name, text)` / `load(name)`: files `<name>.txt` in `SDL_GetPrefPath("fukuruma", "fukuruma")`.
On the web that folder is an IndexedDB-backed file system, mounted and loaded before the game starts and
synced after each save. Non-interactive runs (headless, no-render, scenario, tests) keep values in a Lua
table instead.

### Menu
`fk.ui` keeps the focused item and builds a list of rows each frame (immediate mode): labels, options
(value lists) and buttons; it reads `fk.actions`-style input itself (keys, d-pad, stick with repeat,
mouse, taps) and draws with `fk.gfx.rect` and `fk.gfx.text`. `menu.lua` describes the graphics menu.
While it is open the game's own actions are ignored; the simulation keeps running.

## Risks / Trade-offs

- **TAA ghosting on fast motion** without per-object motion vectors → neighbourhood clamping; velocity
  vectors come with animation if needed.
- **IndexedDB sync timing** (a reload right after saving may lose the last change) → sync after every save.
- **Software-renderer detection by name** → a short, documented list; players can always change the level.
