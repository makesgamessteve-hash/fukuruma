# Proposal

## Why

The game is seen only through the Commander's eyes (CONCEPT §2.6). At a doll's controls that means a cockpit or bridge
around the seat, with windows to look out of, screens showing what the doll knows, and the Commander's hands on the
controls. After `add-doll-chain` the seat views floated in the open air.

## What Changes

- `dolls/cockpit.lua` builds the cabin around a doll's seat. It is sized for the 3.6 m Exosuit the Commander sits in,
  from each doll's `cockpit = {width, height, depth, posts, screens, color, trim}`, using the hull grammar's parts:
  - floor, ceiling and walls;
  - a window wall with posts;
  - a console with glowing screens;
  - the seat;
  - control sticks with the suit's hands on them.

  Sizes run from the Walker's 8 m cab to the Jump Ship's 28 m bridge. The Exosuit has no cockpit, because it is
  steered on foot.
- The screens show the doll's name, what it holds docked, the dolls around it with their distances, its altitude, and
  the controls. The text is drawn where each screen appears, cut to the width the screen covers, so far or small
  screens show less. Away from the Exosuit they replace the visor HUD.
- The seat rig turns the head at most 110° to either side of the doll's front.
- Not in this change: the cabin's sway with the doll's motion, which comes with the vehicle controllers.

## Capabilities

### New Capabilities
- `cockpits`: the cabins, screens and seat limits at every doll's controls.

## Impact

New: `data/scripts/dolls/cockpit.lua` and `tests/lua/cockpit_test.lua`. Changed: the doll definitions (`cockpit`
fields), `data/scripts/{chain,main,dolls}.lua`, and the chain scenario's seat goldens (on purpose).
