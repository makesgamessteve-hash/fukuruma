# Proposal

## Why

Plan M13 asks for accessibility: remapping, subtitles for the ship AI, a colour-blind palette option and motion
comfort, with text kept in string tables for later translation.

## What Changes

- **Key bindings** (`settings/controls.lua`). The settings menu has a row for each main action: use, scan, sprint, dig,
  stun, flare, seal, workshop, outpost and codex. Pressing it waits for the next key; Escape keeps the old one.
  Bindings are saved and applied at start. `fk.input.last_key()` gives the key pressed this frame.
- **Colour vision** (comfort setting). Normal, protanopia, deuteranopia or tritanopia: daltonisation, a 3×3 matrix
  built from Machado et al.'s simulation, applied to the final linear colour (`fk.gfx.colour`).
- **Subtitles.** Everything the ship AI says is already on screen; long lines now wrap. Motion comfort (shake, flashes,
  rumble, head bob, field of view, vignette) was already there.
- **String tables** (`strings.lua`, `strings/en.lua`). The ship AI's lines come from keys, with a fallback to English
  and then to the key. Mods can add languages through the overlay. The rest of the UI text moves over in later
  changes.
- The workshop has no gamepad button for now: every d-pad direction is taken.

## Capabilities

### New Capabilities
- `accessibility`: key bindings, colour vision, string tables.

## Impact

- New: `data/scripts/settings/controls.lua`, `data/scripts/strings.lua`, `data/scripts/strings/en.lua` and
  `tests/lua/strings_test.lua`.
- Changed: `fk/actions.lua` (`actions.def`), `menu.lua`, `settings/comfort.lua`, `ship_ai.lua`, the post shader,
  `frame.{c,h}`, `gl_pipeline.c`, `lua_gfx.c`, `input.c`, `platform.h`, `script.c` and `tests/lua/menu_test.lua`.
