# Proposal

## Why

On phones and tablets every doll must be playable by touch (plan M7: "a touch layout per doll"). Until now the touch
layout was the suit's alone, and the chain's actions had no touch buttons.

## What Changes

- `actions.touch_layout(names)`: only the listed touch buttons are drawn and pressed. nil means all of them.
- The game chooses the layout each frame from where the Commander is:
  - **Always:** menu, view and map.
  - **On foot:** run, scan, dig, and UP to the Walker.
  - **At a doll's controls:**
    - UP and DOWN the chain;
    - DEPLOY when the hold has a doll, and RECALL when there's a child to recall;
    - AUTO when the autopilot has a target, and PORT at a teleport node;
    - CLIMB and DIVE in flying dolls.
- New touch buttons, labelled on screen, are placed so they don't overlap one another or the stick.

## Capabilities

### New Capabilities
- `touch-controls`: the touch layout per doll.

## Impact

Changed: `data/scripts/fk/actions.lua`, `data/scripts/{main,touch_view}.lua`. New: `tests/game/touch_layout.lua` with
two goldens.
