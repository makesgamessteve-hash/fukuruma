# Tasks

## 1. Implementation

- [x] 1.1 `sim.snapshot()` and `sim.restore()` with iteration order, living entities and queued commands
- [x] 1.2 `fk/save.lua`: writer, parser (plain data only), versions and migrations, slots; `fk.seed(n)`
- [x] 1.3 Storage values up to 4 MiB
- [x] 1.4 Sandbox: F5 and F9, Save and Load in the settings menu, a notice with a sound

## 2. Tests

- [x] 2.1 Lua tests: exact round trips, refused texts, snapshot restore and replay, versions, slots
- [x] 2.2 `tests/game/save.lua`; menu tests with the new rows
- [x] 2.3 Browser: a save survives a reload

## 3. Verification

- [x] 3.1 Coverage gates, sanitizers, all CTest tests, web build and browser tests
- [ ] 3.2 CI green on every target; Pages updated
- [ ] 3.3 `openspec validate add-save-system --strict`; archive after deployment
