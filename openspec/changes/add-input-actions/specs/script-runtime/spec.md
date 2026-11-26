# Spec Delta

## MODIFIED Requirements

### Requirement: Lua entry point
On start the engine SHALL run `data/scripts/main.lua`. The script returns a table that may define
`init()`, `input()`, `tick()` and `draw(alpha)`. The engine SHALL call `init` once; then in each frame
it SHALL call `input` once, run the simulation ticks due in that frame (see the simulation spec),
calling `tick` for each, and call `draw` once with the interpolation factor. Missing functions are skipped.

#### Scenario: Game table with all functions
- **GIVEN** `main.lua` returns a table with `init`, `input`, `tick` and `draw`
- **WHEN** a scenario runs for three frames
- **THEN** `init` was called once, and `input`, `tick` and `draw` were each called three times, in that order in every frame

#### Scenario: Game table without draw
- **GIVEN** `main.lua` returns a table with only `tick`
- **WHEN** the game runs
- **THEN** `tick` is called every tick and no error is reported
