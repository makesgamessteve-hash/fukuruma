# Tasks

## 1. Deterministic primitives (C)

- [x] 1.1 `core/rng.c`: FNV-1a 64 hashing, SplitMix64 finaliser, xoshiro256** with float and unbiased range
- [x] 1.2 Lua bindings `fk.rng(key, ...)` (methods `int`, `float`, `range`, `chance`) and `fk.hash(...)`
- [x] 1.3 Fixed Lua string-hash seed in `third_party/lua/luaconf.h`; note it in `THIRD_PARTY_NOTICES.md`

## 2. Tick loop (C)

- [x] 2.1 `fk_ticks_due` (accumulator, at most 8 ticks, interpolation factor)
- [x] 2.2 `app.c`: run due ticks through `fk.sim.step(game)`, then `draw(alpha)`; one tick per frame when headless or in scenarios

## 3. Simulation module (Lua)

- [x] 3.1 `data/scripts/fk/sim.lua`: commands (`on`, `send`, validation and copy), events (`listen`, `emit`), `step`, `reset`
- [x] 3.2 Entities: `create`, `destroy`, `alive`, `set`, `get`, `each` (sparse sets)
- [x] 3.3 `hash()` over the canonical state encoding
- [x] 3.4 `main.lua`: the Jump Ship as an entity spun in `tick`, drawn interpolated

## 4. Tests

- [x] 4.1 C unit tests: rng recorded values, ranges, hashing; `fk_ticks_due` cases from the spec
- [x] 4.2 Lua unit tests for `fk.sim` (commands, validation, events, entities, hash) and `fk.rng`
- [x] 4.3 Fixtures and scenarios use `tick`; a call-order scenario for the entry-point spec
- [x] 4.4 Game test `tests/game/simulation.lua` with a recorded state hash, run with `--no-render` on every CI platform and in the browser

## 5. Verification

- [x] 5.1 Coverage gates (C and Lua at or above 95%), sanitizer build, all CTest tests
- [x] 5.2 CI green on every target; Pages updated
- [x] 5.3 `openspec validate add-simulation-loop --strict`; update `docs/IMPLEMENTATION_PLAN.md` (job system moved to M3); archive after deployment
