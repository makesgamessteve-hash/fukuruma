# Proposal

## Why

The owner: the player needs a reason to walk the dolls, to maintain them and to use what their rooms are for. Every
doll except the Exosuit should hold what a person needs to live: a galley, quarters, a bath and the like. Big dolls
should grow food in a biotope. The interiors need much more detail, starting with the cockpit. The rooms should be
detailed and lazy-loaded, because the huge dolls have too many rooms to keep in memory.

## What Changes

- **A room plan per doll** (`interior.plan`). Every doll except the Exosuit gets:
  - a galley, quarters (more the bigger the doll), a bath, a med bay, an engine room and a cargo deck;
  - from 1 km up, also a workshop, a lab, life support and a drone bay;
  - from 6 km up, also a biotope (three slots wide and 9 m tall).
  - The suit bay and the clone bay stay where they were.
- **Furniture** (`interior/rooms.lua`). A catalog of room types, each with its furniture made of hull parts and its
  glowing lights. One fixture per room type.
- **Streaming.** Rooms are built one at a time (`interior.room_mesh`), with furniture and lights:
  - rooms within 40 m of the Commander are built, at most two a frame;
  - rooms beyond 70 m are let go;
  - a door opening or shutting rebuilds only its room;
  - the corridor and hangars stay loaded.
- **Living aboard** (`living.lua`):
  - Hunger, fatigue and grime rise.
  - Fixtures: eat, sleep, wash, heal, maintain (engine room and life support), harvest, and the workbench and lab menus.
  - Engine wear slows a doll above half.
  - Spent life support stops the suit's restore aboard.
  - A starving or exhausted Commander does not mend aboard and slowly wears down outside.
  - The visor warns; the cockpit screens show the maintenance state.
  - Each action has a feedback bundle with a new sound.
- **Detailed cockpits.** A seat with a pedestal, headrest and armrests; a sloped console; side consoles with lit button
  rows; an overhead panel; wall ribs; floor grating; strip lights.
- **Room lights** take the colour of their room's type.
- **Concept.** Section 2.5 gains "Why the Commander walks the dolls".

## Capabilities

### Modified Capabilities
- `vessel-interiors`: the room plan, furniture and streaming.
- `exosuit-survival`: needs and the rooms that meet them; doll upkeep.
- `cockpits`: the detailed cabin.

## Impact

- New: `interior/rooms.lua`, `living.lua`, `tests/lua/living_test.lua`, `tests/game/living.lua`, six sounds.
- Changed: `interior.lua`, `chain.lua` (fixture, speed and screen hooks), `survival.lua` (weary and air hooks),
  `dolls/cockpit.lua`, `main.lua`, `feedback.lua`.
- The living state is kept on the survival entity and made when missing, so release 1.0 saves load.
- Goldens of cockpit views and state hashes change on purpose.
