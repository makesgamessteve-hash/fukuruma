# Proposal

## Why

Exploration needs persistence: the plan stores "the world seed plus all deltas … as versioned Lua-table text" in the
user's folder and IndexedDB on the web (`docs/IMPLEMENTATION_PLAN.md` §3.11), and M1's tests require a save/load
round trip that keeps the Exosuit's position.

## What Changes

- **Simulation snapshots:** `sim.snapshot()` and `sim.restore()` cover the tick, the next entity ID, the living
  entities, every component with its iteration order, and the commands not yet applied, so a restored game runs on
  exactly as the original would.
- **`fk/save.lua`:** a save is the version, the world seed, the simulation snapshot (the deltas from the generated
  world; later milestones add terrain and interior edits) and game data. It is written as Lua-table text and read by a
  parser that only accepts plain data, never code. Migrations upgrade older versions; newer ones are refused.
- **Slots** in `fk.storage` (`save_<slot>`), so desktop saves land in the user's folder and browser saves in IndexedDB;
  values may now be up to 4 MiB.
- **`fk.seed(n)`** sets the world seed when a save is loaded.
- **The sandbox:** F5 quick-saves and F9 quick-loads, also from the settings menu, with a notice and a sound.

**Out of scope:** several named slots in the menu, autosave, cloud saves, chunk and interior deltas (with M5 and M8).

**Proving game test:** `tests/game/save.lua` saves after walking, moves on, loads, and checks that the position and
the whole state hash are back and the game continues; loading without a save says so.

## Capabilities

### New Capabilities
- `save`: snapshots, the save format, versions and slots.

### Modified Capabilities
- `storage`: values up to 4 MiB.
- `simulation`: snapshots.

## Impact

`data/scripts/fk/sim.lua` (snapshot, restore), new `data/scripts/fk/save.lua`, `script.c` (`fk.seed(n)`),
`lua_storage.c` (limit), `main.lua` and `menu.lua` (quick save and load).
