# Proposal

## Why

Screenshots showed the dolls as a few coloured boxes, far from the concept's detailed procedural hulls. Lathes were
open tubes, and legs were axis-aligned boxes that parted at the knees and hips. The owner asked for every doll to be
redesigned: much more detailed, more interesting, science-fiction looking, and without gaps in the model.

## What Changes

- **The hull grammar** (`dolls/hull.lua`):
  - new closed part kinds: `taper` (wedges, slopes, frustums), oriented `strut` beams whose ends overlap at joints,
    `ball` joints and domes, and `torus` rings;
  - lathes on any axis with their ends capped;
  - `mirror` and `array` copies for every part kind;
  - `glow` parts (windows, engines, beacons, visors) built into a second mesh that is drawn with emission;
  - legs as thighs and shins on ball joints, with armoured knees, pistons and broad feet. The feet stand where they
    did, and the colliders follow the new knees.
- **All seven dolls redesigned:**
  - the Exosuit: armoured humanoid, glowing visor, backpack;
  - the Walker: armoured chassis, cockpit module, manipulator arms, sample pod, sensor mast, headlights;
  - the Land Explorer: a stepped walking city with lit window bands, domes, towers, cranes, radiators and a bridge
    tower;
  - the Continental Explorer: a rock mountain under a city platform with citadel towers, a lit rim, lift-engine
    nacelles and docking bays;
  - the Drop Ship (reworked on the owner's request: not a shuttle): a ball with an armoured belt, small fins, two huge
    engine nacelles and a big central engine, and huge hangar bay doors in its flanks and belly. Its seat moved to the
    front of the ball, above the belt;
  - the Space Station: a spindle, twin habitat rings on spokes with window belts, solar arrays, docking arms and a
    command arm;
  - the Jump Ship: a spine with a hammerhead bow, the glowing jump ring, hangar bays, radiator wings, an engine cluster
    and a bridge tower.
  Each doll keeps a clear view ahead of its seat: nothing stands in front of the cockpit's windows.
- **Rendering.** The lights mesh is drawn in the world and in hangars. A doll nearer than where the planetary depth
  slice starts pulls that slice in, so the station, the Jump Ship and Drop Ships high up are no longer clipped away.

## Capabilities

### Modified Capabilities
- `doll-chain`: detailed, closed hulls with lights.

## Impact

- Changed: `data/scripts/dolls/*.lua`, `chain.lua` and `main.lua`.
- Extended: `tests/lua/chain_test.lua`, which checks that every part kind and every doll's parts are closed.
- Goldens with dolls in view, and the recorded hashes (the leg colliders), change on purpose.
