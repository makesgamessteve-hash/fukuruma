# Proposal

## Why

The game is played in VR in the browser (CONCEPT §7; plan M7: "the WebXR session, stereo rendering, controller mapping
and haptics"). In VR the player's head is the Commander's head.

## What Changes

- **Stereo rendering in the engine:** `fk.gfx.stereo(ipd)` renders the frame once per eye.
  - Each eye's camera is moved half the distance between the eyes to its side and sees half the window's width.
  - Both eyes are drawn side by side to the window, and the screenshots capture both.
  - TAA is off in stereo, because one eye's history would smear into the other's.
- **The headset in C:** `fk_web_xr` takes each session frame's head rotation and eye distance, and `fk.input.xr()`
  gives them to Lua. In a session the game renders in stereo, and the head turns the view.
- **Controllers:** `fk_web_xr_pad` turns the headset's controllers into the existing gamepad actions:
  - the left stick moves and the right stick looks;
  - the right trigger digs and right A scans;
  - the left trigger runs and left X opens the outside view;
  - right B goes up the chain and left Y down it.

  Rumble pulses the controllers' haptics.
- **`web/xr.js`:**
  - shows ENTER VR where the browser offers immersive VR;
  - starts the session, which then drives the game's frames;
  - reports each frame's pose and the controllers, and sends the game's window drawing to the headset's framebuffer;
  - restores the page when the session ends.
- **Test harness:** `t.xr(...)` and `t.xr_pad(...)` play a headset's frames in scenarios.
- **Shortcuts, for M7's tuning:**
  - The picture is drawn at the canvas's size, not the headset's resolution.
  - Each eye uses the game's projection rather than the headset's.
  - Head roll is ignored.

## Capabilities

### New Capabilities
- `webxr`: VR in the browser: the session, stereo, head and controllers.

## Impact

New: `web/xr.js` and `tests/game/stereo.lua` with a golden. Changed: `engine/src/gfx/{gl_pipeline.c,frame.h}`,
`engine/src/script/{lua_gfx.c,script.c}`, `engine/src/platform/{input.c,platform.h}`, `engine/src/app/app.c`,
`data/scripts/main.lua`, `CMakeLists.txt` and `tests/web/smoke.mjs` (a mocked headset).
