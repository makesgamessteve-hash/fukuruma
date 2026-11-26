# Design

## Context

The simulation is deterministic and holds all game state as plain Lua data (`fk.sim`); presentation is rebuilt every
frame. `fk.storage` already writes text to the user's folder or IndexedDB.

## Decisions

### Save the simulation, not the presentation
A save holds the version, the world seed, `sim.snapshot()` and optional game data. Animation, camera, particles and
music are presentation and continue from the loaded state. Command handlers and listeners are code and are set up by
`init`, not saved.

### Snapshots keep iteration order
The state hash covers values only, but ticks iterate components in their sparse sets' order. Snapshots therefore store
each component's ID list as well as its values, the living entities (some have no components) and the queued commands,
so a restored game produces the same hashes as the original from then on. Saving happens between ticks (in
`input()`), so a snapshot is always a whole tick.

### Lua-table text, parsed, never executed
The writer produces `-- fukuruma save` and `return { … }` with sorted keys, `%q` strings and exact numbers (`%.17g`;
floats with an integral value get `.0`, so integers and floats keep their types and the hash stays the same). The reader
is a small recursive-descent parser for exactly that subset (tables, strings, numbers, booleans, comments; at most 24
levels deep). Running the text with `load` would let a shared save run code, so it is never executed. CRLF line breaks
are accepted.

### Versions and migrations
`save.VERSION` is 1. `save.MIGRATIONS[n]` upgrades version n data to n + 1; loading applies them in order and refuses
saves from newer game versions with a clear message.

### Slots in fk.storage
A slot `quick` is stored as `save_quick`. The storage limit grows from 64 KiB to 4 MiB, enough for M1 to M4 saves;
chunk deltas will move to their own files when terrain arrives.

### Loading in the sandbox
After a load the sandbox resets its input comparison to the loaded wish (so it sends the next change), lets the camera
jump instead of flying across the map, and shows "Game loaded".

## Risks / Trade-offs

- Whole-state snapshots grow with the world; deltas against generated content keep them small (M5 onwards).
- The parser is Lua: fine for saves of a few megabytes.
