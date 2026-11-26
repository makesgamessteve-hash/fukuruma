# Design

## Context

M0 calls `update(dt)` and `draw()` once per frame. The plan (§3.2) asks for a fixed 60 Hz simulation
that changes state only through commands, emits events for presentation, has entities with stable IDs
and seeded random streams, so runs are reproducible and co-op can be added later by sending commands
over a network.

## Goals / Non-Goals

**Goals:** fixed tick with interpolation; commands, events, entities and a state hash in Lua; random
streams and hashing in C; identical results on every platform.

**Non-Goals:** job system (moved to M3, the first change with background work); input (next change);
save files (the next save change reuses the state encoding); enforcing that game code changes state
only through commands (it is a rule for scripts, checked by review and determinism tests, not by the
engine).

## Decisions

### The tick loop lives in C, the simulation rules in Lua
`app.c` decides how many ticks are due (`fk_ticks_due`, a pure function with unit tests) and calls
`fk.sim.step(game)` for each. `data/scripts/fk/sim.lua` applies the queued commands, calls
`game.tick()`, advances the tick counter and delivers the events. Commands, events and entities are
not hot loops, and Lua keeps them short and moddable. Components that later need C speed (transforms
for physics and rendering) get C storage in the changes that need them.

### Commands
`fk.sim.on(name, handler)` registers a handler; `fk.sim.send(name, args)` validates and deep-copies
`args` and appends it to the queue. `step` swaps the queue out before applying it, so commands sent by
handlers go to the next tick. Validation: finite numbers, strings, booleans, tables with string or
integer keys, at most 8 levels (which also catches cycles).

### Entities
IDs come from a counter that only grows. Each component is a sparse set: a dense array of IDs (the
iteration order), an index from ID to position and the values. Removal swaps the last element into
the gap, so the order depends only on the sequence of operations. `fk.sim.each(name)` iterates over a
snapshot, so entities may be destroyed during iteration.

### State hash
The state (tick, next ID, components by name, IDs ascending) is encoded canonically: tables with sorted
keys, numbers as `string.pack` bytes (`<j` for integers, `<d` for floats), strings length-prefixed,
type tags in between. `fk.hash` hashes the encoding. The encoding is also the starting point for save files.

### Random streams and hashing in C
`core/rng.c`: FNV-1a 64 for hashing keys, the SplitMix64 finaliser to turn the hash into a seed,
xoshiro256** for the stream. Keys are fed as explicit little-endian bytes with type tags. Floats are the
top 53 bits times 2^-53; ranges use rejection sampling (no modulo bias). Only integer operations, so
every platform gives the same numbers; unit tests pin the first values for seed 1 and key "test".

### Lua table order
Lua 5.4 seeds its string hash from `time()` and memory addresses, so `pairs` order changes between runs.
`third_party/lua/luaconf.h` defines `luai_makeseed` as 0 (hash flooding is not a threat in a game).
Simulation code still never depends on `pairs` order: everything that must be ordered uses arrays or sorted keys.

### Frame timing
Windowed runs accumulate real time; at most 8 ticks run per frame and any further backlog is dropped
(the game slows down instead of freezing). Headless runs and scenarios run one tick per frame with
`alpha = 1`, which keeps game tests reproducible.

## Risks / Trade-offs

- **Lua simulation speed** → fine for M1's handful of entities; per-entity hot paths move to C when
  physics and rendering need them.
- **Games can bypass commands** → a script rule, enforced by the state-hash scenario on every platform.
- **Patched `luaconf.h`** → one line, recorded in `THIRD_PARTY_NOTICES.md`; re-apply when updating Lua.
