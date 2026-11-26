# Proposal

## Why

Everything in M1 and later (input, physics, animation, game feel, saves, and co-op after 1.0) needs a
simulation that advances in fixed, deterministic steps and changes state only through commands. M0's
per-frame `update(dt)` depends on the frame rate and lets any code change any state at any time. This
change replaces it with the simulation core the plan describes (`docs/IMPLEMENTATION_PLAN.md` §3.2).

## What Changes

- **BREAKING (game scripts):** `main.lua` defines `tick()` (called at a fixed 60 Hz) and `draw(alpha)`
  (once per frame, with the interpolation factor) instead of `update(dt)` and `draw()`.
- The engine runs as many ticks per frame as real time requires (at most 8, then it slows down rather
  than spiralling); headless and scenario runs advance exactly one tick per frame.
- A Lua simulation module `fk.sim` (in `data/scripts/fk/sim.lua`): commands with registered handlers,
  applied in order at the start of the next tick, with plain-data arguments that are validated and
  copied; events delivered to listeners after each tick; entities with IDs that are never reused and
  plain-data components; a hash of the complete simulation state.
- Deterministic random streams `fk.rng(...)` and hashing `fk.hash(...)` in C, seeded from the world
  seed and a key path, identical on every platform.
- Lua's string hashing uses a fixed seed (it used the clock and memory addresses), so table iteration
  order no longer changes between runs.
- The placeholder Jump Ship becomes an entity that spins in `tick` and is drawn interpolated.

**Out of scope:** the job system (moved to the first change that has background work, M3), input
(`add-input-actions`), save files (`add-save-system` will reuse the state encoding), networking.

**Proving game test:** `tests/game/simulation.lua` creates entities through commands using random
streams, runs 120 ticks and compares the state hash with a recorded value. It runs with `--no-render`
on Linux, Windows and macOS and in the browser, so it checks determinism across platforms.

## Capabilities

### New Capabilities

- `simulation`: the fixed-rate tick, commands, events, entities, random streams and the state hash.

### Modified Capabilities

- `script-runtime`: the game table's functions change from `update(dt)`/`draw()` to `tick()`/`draw(alpha)`.

## Impact

- `engine/src/app/app.c` (tick loop), new `engine/src/core/rng.c`, `engine/src/script/script.c`
  (`fk.rng`, `fk.hash`), `third_party/lua/luaconf.h` (fixed hash seed, noted in `THIRD_PARTY_NOTICES.md`).
- `data/scripts/main.lua`, new `data/scripts/fk/sim.lua`; Lua tests, fixtures and scenarios that used
  `update`.
