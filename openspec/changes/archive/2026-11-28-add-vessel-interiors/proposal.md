# Proposal

## Why

Fukuruma is a nesting doll that the player explores on foot. The Commander walks as a human through rooms made for
people inside every doll, puts the Exosuit on in a suit bay to go outside, and boards the next doll by walking up its
ramp in the parent's hangar and then taking its controls (plan M8; owner's decision, 2026-11-27). This change covers
plan M8's `add-human-on-foot`, `add-vessel-interiors` and `add-hangar-boarding`.

## What Changes

- **Layouts.** `interior.lua` builds a fixed layout per doll kind. A corridor spine runs back from the bridge (the
  doll's cockpit). Side rooms open off it through doors: the suit bay where the doll carries the Exosuit, the Jump
  Ship's clone bay, quarters, and a drone bay on large dolls. Behind them is one hangar per carried kind, sized for
  that doll docked inside at full scale, with a ramp up into it. The free space is a set of rectangles, and the walls
  stand the body's radius beyond them.
- **On foot.** `state.walk` holds the Commander walking as a human (eye 1.65 m, 1.4 m/s) in a doll's frame. The move
  command walks there and slides along walls. Doors are shut or open (`state.doors`); a shut door blocks the walk,
  and a door does not close on the Commander. Both are part of the saved state.
- **The use command** (F, the gamepad's B, a touch button) does what is in reach, and the visor shows what F will
  do:
  - enter the doll from the Exosuit through its suit bay (the suit goes into the hold);
  - stand up from the seat;
  - take the controls;
  - open or close a door;
  - walk up a ramp into a docked doll;
  - go down its ramp again;
  - launch the docked doll from its own bridge;
  - suit up in the suit bay and go outside.
- **Presentation.** While the Commander walks, the rooms are drawn in the doll's frame instead of its hull: the doll's
  cockpit, with a doorway now in its back wall, the docked dolls in their hangars, and the nearest room lights.
- **Rendering.** A new `indoor` draw option keeps starlight off rooms inside a doll. It is stored in the normal
  buffer's alpha. The seat-to-seat `board` command of M6 stays for tests and the autopilot.

## Capabilities

### New Capabilities
- `vessel-interiors`: rooms inside the dolls, walking as a human, doors, the use command, hangar boarding.

### Modified Capabilities
- `rendering`: the `indoor` draw option.

## Impact

- New: `data/scripts/interior.lua`, `tests/lua/interior_test.lua`, `tests/game/interiors.lua` with its goldens.
- Changed: `data/scripts/{chain,main,feedback}.lua`, `data/scripts/dolls/cockpit.lua`, the G-buffer and lighting
  shaders, `frame.h`, `gl_pipeline.c`, `lua_gfx.c`.
- The recorded hashes are unchanged: nothing walks until F is pressed.
