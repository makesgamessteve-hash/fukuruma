# script-runtime Specification

## Purpose

Defines how the engine starts and runs the Lua game, what scripts are allowed to do, and how script
errors are reported, so the game logic can be written and modded in Lua.

## Requirements

### Requirement: Lua entry point
On start the engine SHALL run `data/scripts/main.lua`. The script returns a table that may define
`init()`, `input()`, `tick()` and `draw(alpha, dt)`. The engine SHALL call `init` once; then in each frame
it SHALL call `input` once, run the simulation ticks due in that frame (see the simulation spec),
calling `tick` for each, and call `draw` once with the interpolation factor and the frame's duration in
seconds, at most 0.25 s. Missing functions are skipped.

#### Scenario: Game table with all functions
- **GIVEN** `main.lua` returns a table with `init`, `input`, `tick` and `draw`
- **WHEN** a scenario runs for three frames
- **THEN** `init` was called once, and `input`, `tick` and `draw` were each called three times, in that order in every frame

#### Scenario: Game table without draw
- **GIVEN** `main.lua` returns a table with only `tick`
- **WHEN** the game runs
- **THEN** `tick` is called every tick and no error is reported

#### Scenario: Frame time in scenarios
- **WHEN** a scenario runs
- **THEN** `draw` receives 1/60 s as the frame time in every frame, so presentation is reproducible

#### Scenario: A long hitch
- **WHEN** a frame comes 3 s after the previous one (loading, a hidden browser tab)
- **THEN** `draw` receives 0.25 s

### Requirement: Script modules
Scripts SHALL be able to load other scripts with `require("a.b")`, which loads `data/scripts/a/b.lua`
through the engine's data folder lookup. `require("game")` SHALL return the table returned by
`data/scripts/main.lua`.

#### Scenario: Requiring a module
- **GIVEN** a file `data/scripts/dolls/walker.lua` that returns a table
- **WHEN** a script calls `require("dolls.walker")`
- **THEN** it receives that table

#### Scenario: The game table
- **WHEN** a scenario calls `require("game")` and replaces its `draw` function
- **THEN** the following frames are drawn by the new function

### Requirement: Sandboxed scripts
Game scripts SHALL NOT have access to the Lua `os`, `io` and `debug` libraries, `loadfile`, `dofile`
or loading native libraries. Scripts read files only through the engine.

#### Scenario: Script tries to open a file directly
- **WHEN** a game script calls `io.open("/etc/passwd")`
- **THEN** the call fails with a Lua error because `io` is not defined
- **AND** the error is reported as a script error

### Requirement: Drawing from scripts
Scripts SHALL be able to create a mesh from Lua tables of vertex positions, vertex colours (the base
colour), optional normals (computed from the triangles when absent) and triangle indices; set the camera
(view and projection matrices), the star light, the ambient light, point lights and the background
colour; and draw meshes with a model matrix and a material (roughness, metalness, emission).

#### Scenario: Spinning placeholder
- **GIVEN** `main.lua` creates a mesh from tables and draws it each frame with a growing rotation angle
- **WHEN** two frames are rendered at different times
- **THEN** the mesh appears in both frames at different rotations

#### Scenario: Normals computed
- **WHEN** a mesh is created without normals
- **THEN** each vertex gets the normalised sum of the normals of the triangles that use it

#### Scenario: Invalid material
- **WHEN** a script draws with a roughness outside 0..1
- **THEN** a script error names the field

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
