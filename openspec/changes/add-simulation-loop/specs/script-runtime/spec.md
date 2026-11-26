# Spec Delta

## MODIFIED Requirements

### Requirement: Lua entry point
On start the engine SHALL run `data/scripts/main.lua`. The script returns a table that may define
`init()`, `tick()` and `draw(alpha)`. The engine SHALL call `init` once, then run the simulation ticks
due in each frame (see the simulation spec), calling `tick` for each, and then call `draw` once with
the interpolation factor. Missing functions are skipped.

#### Scenario: Game table with all functions
- **GIVEN** `main.lua` returns a table with `init`, `tick` and `draw`
- **WHEN** a scenario runs for three frames
- **THEN** `init` was called once, and `tick` and `draw` were each called three times, `tick` before `draw` in every frame

#### Scenario: Game table without draw
- **GIVEN** `main.lua` returns a table with only `tick`
- **WHEN** the game runs
- **THEN** `tick` is called every tick and no error is reported
