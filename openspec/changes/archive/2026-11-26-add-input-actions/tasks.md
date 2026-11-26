# Tasks

## 1. Raw input (C)

- [x] 1.1 `platform/input.c`: SDL event translation (keys, mouse, gamepads, touches), last-used device, per-frame reset
- [x] 1.2 Gamepad subsystem and opening pads on connect
- [x] 1.3 Emulation functions that build SDL events for scenarios
- [x] 1.4 `fk.input` bindings: `key`, `mouse`, `mouse_button`, `axis`, `button`, `touches`, `device`

## 2. Engine loop and harness

- [x] 2.1 `input()` called once per frame before the ticks
- [x] 2.2 Scenario helpers `t.key`, `t.mouse_button`, `t.gamepad_axis`, `t.gamepad_button`, `t.touch`

## 3. Actions (Lua)

- [x] 3.1 `data/scripts/fk/actions.lua`: `define`, `bind`, `update`, `value`, `held`, `pressed`, touch stick and buttons, `touch_controls`
- [x] 3.2 `main.lua`: turn and boost actions → `ship.control` commands; touch controls drawn in touch mode

## 4. Tests

- [x] 4.1 C unit tests for event translation and emulation
- [x] 4.2 Lua unit tests for actions (axes, dead zone, edges, remapping, touch stick and buttons)
- [x] 4.3 Game test `tests/game/input.lua` (keys, gamepad, touch, remap; golden image with touch controls)
- [x] 4.4 Browser test: tap in phone emulation, `touch` scenario passes

## 5. Verification

- [x] 5.1 Coverage gates, sanitizers, all CTest tests
- [x] 5.2 CI green on every target; Pages updated
- [x] 5.3 `openspec validate add-input-actions --strict`; archive after `add-simulation-loop`, once deployed
