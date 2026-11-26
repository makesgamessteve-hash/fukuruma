# Proposal

## Why

The game cannot be controlled yet. Every doll needs keyboard and mouse, gamepad and touch controls
(touch automatically on phones), bindings players can change, and game tests that can press keys and
touch the screen. Input is the first source of simulation commands.

## What Changes

- The platform layer turns SDL keyboard, mouse, gamepad and touch events into one raw input state, and
  remembers which kind of device was used last. Gamepads are opened when connected.
- `fk.input` (C): raw state for scripts (keys by name, mouse, gamepad axes and buttons, touches in
  normalised screen coordinates, the last-used device).
- `fk.actions` (Lua, `data/scripts/fk/actions.lua`): named axis and button actions with bindings per
  device, dead zones, press edges, a virtual stick and touch buttons for touch screens, and `bind` for
  remapping at runtime.
- **BREAKING (game scripts):** the game table may define `input()`, called once per frame before the
  ticks; this is where actions become commands.
- Scenarios can emulate input: `t.key`, `t.mouse_button`, `t.gamepad_axis`, `t.gamepad_button` and `t.touch`
  inject events through the same path as real ones.
- The placeholder Jump Ship can be turned with A/D or the arrow keys, the left stick, or the touch stick,
  and sped up with Space, the A button or a touch button. The touch controls are drawn while the last
  input came from touch.

**Out of scope:** relative (captured) mouse look and a remapping menu (they come with the Exosuit
controls and the settings menu), haptics (`add-game-feel`), saving bindings (`add-save-system`).

**Proving game tests:** `tests/game/input.lua` turns the ship with emulated keys, gamepad and touch and
compares a screenshot with the touch controls visible. In the browser, `tests/web/smoke.mjs` taps the
canvas in phone emulation and the `touch` scenario passes once the game has seen the touch.

## Capabilities

### New Capabilities

- `input`: raw device input, actions with bindings, remapping and the touch controls.

### Modified Capabilities

- `script-runtime`: the game table gains `input()`, called each frame before the ticks.
- `test-harness`: scenarios can emulate keyboard, mouse, gamepad and touch input.

## Impact

- `engine/src/platform/` (event translation, gamepads), `engine/src/script/script.c` (`fk.input`),
  `engine/src/app/app.c` (input phase, scenario helpers), new `data/scripts/fk/actions.lua`,
  `data/scripts/main.lua`, tests and the browser test.
