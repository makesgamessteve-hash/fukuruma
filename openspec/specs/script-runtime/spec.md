# script-runtime Specification

## Purpose

Defines how the engine starts and runs the Lua game, what scripts are allowed to do, and how script
errors are reported, so the game logic can be written and modded in Lua.

## Requirements

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

### Requirement: Script modules
Scripts SHALL be able to load other scripts with `require("a.b")`, which loads `data/scripts/a/b.lua`
through the engine's data folder lookup.

#### Scenario: Requiring a module
- **GIVEN** a file `data/scripts/dolls/walker.lua` that returns a table
- **WHEN** a script calls `require("dolls.walker")`
- **THEN** it receives that table

### Requirement: Sandboxed scripts
Game scripts SHALL NOT have access to the Lua `os`, `io` and `debug` libraries, `loadfile`, `dofile`
or loading native libraries. Scripts read files only through the engine.

#### Scenario: Script tries to open a file directly
- **WHEN** a game script calls `io.open("/etc/passwd")`
- **THEN** the call fails with a Lua error because `io` is not defined
- **AND** the error is reported as a script error

### Requirement: Drawing from scripts
Scripts SHALL be able to clear the screen to a colour, create a mesh from Lua tables of vertex
positions, vertex colours and triangle indices, and draw that mesh with a position and rotation.

#### Scenario: Spinning placeholder
- **GIVEN** `main.lua` creates a mesh from tables and draws it each frame with a growing rotation angle
- **WHEN** two frames are rendered at different times
- **THEN** the mesh appears in both frames at different rotations

### Requirement: Script errors are reported
A Lua error SHALL be logged with file, line and stack traceback. In a windowed run the error message
SHALL be shown on screen and the window SHALL stay open. In headless runs the game SHALL exit with a
non-zero exit code.

#### Scenario: Error in update during a windowed run
- **WHEN** `update` raises an error in a windowed run
- **THEN** the log contains the file name, line number and traceback
- **AND** the window shows the error message instead of closing

#### Scenario: Error during a headless run
- **WHEN** a script raises an error while the game runs with `--headless`
- **THEN** the game exits with a non-zero exit code after logging the error
