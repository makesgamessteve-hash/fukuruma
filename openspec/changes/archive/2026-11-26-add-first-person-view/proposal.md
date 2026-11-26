# Proposal

## Why

The owner wants the game seen through the Commander's eyes at all times (CONCEPT §2.6, decision 12): walking and
steering happen from inside the Exosuit or a vehicle, and an outside view exists only for orientation. The M1
sandbox still follows the suit with a chase camera. M2 starts by turning that around, before reference frames,
orbits and physics build on the camera.

## What Changes

- **Helmet view:** the camera sits at the eyes in the animated head of the Exosuit (head bob scaled by a comfort
  setting); the head itself is hidden from inside. The mouse (captured, relative mode / pointer lock), the right
  stick and a finger dragged on the right half of a touch screen turn the view. Walking goes where the Commander
  looks, and the suit turns to face that way. The chase camera is removed.
- **Outside view:** V, the gamepad's Back button or the touch button VIEW switches to the survey drone, which orbits
  the suit for orientation only: the suit holds still, scanning is off, and looking orbits the drone. The same input
  returns to the helmet.
- **Visor HUD:** a compass with heading, the speed and the scanner's charge (scans now recharge for two seconds),
  a visor frame and a vignette while turning fast. The drone view shows a feed with scanlines and a "view only" note.
- **Comfort:** head bob (100%, 50%, off), field of view (60–90) and the turning vignette in the settings menu.
- **Engine:** `fk.input.capture(on)`, `pose:scale(node, s)`, `t.mouse_move(dx, dy)` for scenarios; emulated input
  from a scenario now reaches the next frame (input frame end runs before the scenario step).

## Capabilities

### Modified Capabilities
- `effects`: helmet and drone camera rigs replace the chase rig; first-person view, outside view, visor HUD; new
  comfort options.
- `input`: looking with mouse, right stick and touch; mouse capture; the touch VIEW button.
- `animation`: scaling nodes.
- `test-harness`: emulated mouse motion.

## Impact

`data/scripts/main.lua`, `fk/camera.lua`, `fk/actions.lua`, `hud.lua` (new), `menu.lua`, `touch_view.lua`,
`settings/comfort.lua`, `fk/ui.lua` (row height 11 so 21 rows fit); `engine/src/platform/{platform,input}.c`,
`script/{script,lua_anim}.c`, `app/app.c`; tests and goldens of every sandbox scenario (regenerated on purpose:
the view changed), the simulation hash (the suit stores the look direction and scan charge); README controls.
