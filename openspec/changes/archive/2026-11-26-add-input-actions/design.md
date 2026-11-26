# Design

## Context

M1's sandbox needs the placeholder to be controlled with keyboard, gamepad and touch, and game tests
must drive it. Plan §3.13: action maps in Lua, touch layout shown automatically, remappable bindings.

## Goals / Non-Goals

**Goals:** one raw input state fed by SDL events; Lua actions with bindings per device; touch stick
and buttons; emulated input for scenarios through the real event path; the browser's touch path tested.

**Non-Goals:** captured-mouse look, a remapping menu, saved bindings, haptics, text input.

## Decisions

### Raw state in the platform layer
`platform/input.c` is the only code that understands SDL input events. `platform/main.c` passes each
`SDL_Event` to `fk_input_event`, which updates keys (by scancode), mouse position and per-frame motion
(normalised to the window), merged gamepad axes and buttons, up to 10 touches, and the last-used device.
Gamepads are opened on `SDL_EVENT_GAMEPAD_ADDED`. Mouse events that SDL or the browser synthesise from
touches (`SDL_TOUCH_MOUSEID`, or within 500 ms of a touch) do not switch the device to "mouse", so a
phone stays in touch mode.

### Emulation through the same path
The scenario helpers (`t.key`, `t.mouse_button`, `t.gamepad_axis`, `t.gamepad_button`, `t.touch`) call
`fk_input_emulate_*`, which build `SDL_Event`s and pass them to `fk_input_event`. No-render runs have no
SDL video, but the input state still works, so input scenarios also run on the Windows and macOS CI runners.

### Actions in Lua
`data/scripts/fk/actions.lua` holds the action definitions and evaluates them once per frame in
`update()` (the game calls it from `input()`). Axis value: the largest-magnitude of keys (-1/+1),
gamepad axis (dead zone 0.2, rescaled to reach 1) and touch-stick axis. Buttons track the previous
frame for press edges. `bind(name, changes)` replaces fields of a definition. The touch stick is
anchored where a touch first lands on the left half; its displacement is measured in units of 12% of the
screen height (using the window's aspect ratio). Touch buttons are circles in the same units, placed by
the game.

### Input becomes commands
Input is sampled once per frame in `game.input()`, before the ticks. The game sends a command only when
an action's value changes (here `ship.control`), so a held key is one command, not 60 per second.

### Drawing the touch controls
M0's renderer can draw meshes with a matrix, so the stick and buttons are circle meshes drawn with an
orthographic matrix at the near plane. They become proper UI widgets with the UI in `add-render-pipeline`.

## Risks / Trade-offs

- **Browser compatibility mouse events after touches** → the 500 ms rule; checked by the browser test.
- **Merged gamepads** (all pads drive the same state) → fine for a single-player game; per-player pads come with co-op.
