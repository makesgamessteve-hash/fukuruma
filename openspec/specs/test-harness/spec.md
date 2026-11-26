# test-harness Specification

## Purpose

Defines the command-line modes the game binary offers for automated testing: headless runs, Lua unit
tests, scripted game-test scenarios and golden screenshots, with exit codes that CI can rely on.

## Requirements

### Requirement: Headless and render-free modes
With `--headless` the game SHALL run without a visible window and still render every frame to an
offscreen image. With `--no-render` the game SHALL run its scripts without creating a graphics
context and without rendering.

#### Scenario: Headless run on a machine without a display
- **WHEN** the game is started with `--headless` on a machine with no display server
- **THEN** it runs and renders frames without opening a window

#### Scenario: Render-free run
- **WHEN** the game is started with `--no-render`
- **THEN** scripts run each frame and no graphics context is created

### Requirement: World seed
The game SHALL accept `--seed <n>` (an unsigned 64-bit integer, default 1) and make the value
available to scripts.

#### Scenario: Seed passed on the command line
- **WHEN** the game is started with `--seed 42`
- **THEN** scripts read the seed as 42

### Requirement: Lua unit tests
With `--test <dir>` the game SHALL run every `*_test.lua` file in that folder and its subfolders,
print one result line per test, and exit with code 0 only when every test passed.

#### Scenario: One failing test
- **GIVEN** a test folder with three tests, one of which fails an assertion
- **WHEN** the game is started with `--test` on that folder
- **THEN** it prints two passes and one failure with its message
- **AND** it exits with a non-zero exit code

### Requirement: Game-test scenarios
With `--scenario <file>` the game SHALL run the Lua scenario in that file with a fixed time step of
1/60 s per frame, independent of real time. The exit code SHALL be 0 when the scenario completes
with all expectations met, 1 when an expectation fails or a script error occurs, and 2 when the
scenario's timeout is exceeded.

#### Scenario: Passing scenario
- **WHEN** a scenario whose expectations all hold is run
- **THEN** the game exits with code 0

#### Scenario: Failing expectation
- **WHEN** a scenario expectation does not hold
- **THEN** the game logs the failed expectation with its file and line
- **AND** exits with code 1

#### Scenario: Timeout
- **WHEN** a scenario with a timeout of 5 seconds of game time has not completed after 300 frames
- **THEN** the game exits with code 2

### Requirement: Golden screenshots
A scenario SHALL be able to compare the current frame with a reference image `tests/golden/<name>.png`.
The comparison fails when more than 0.5% of pixels differ beyond a small colour tolerance; a diff image
is then written to the test output folder. With `--update-golden` the reference image is written instead.

#### Scenario: Matching frame
- **WHEN** a scenario takes a screenshot that matches its reference image
- **THEN** the scenario continues

#### Scenario: Different frame
- **WHEN** a screenshot differs from its reference image in more than 0.5% of pixels
- **THEN** the scenario fails with exit code 1
- **AND** a diff image is written to the test output folder

#### Scenario: Screenshots without rendering
- **WHEN** a scenario that takes screenshots runs with `--no-render`
- **THEN** the screenshot steps are skipped and logged, and do not fail the scenario

#### Scenario: Screenshots in the browser
- **WHEN** a scenario that takes screenshots runs in the browser
- **THEN** the screenshot steps are skipped and logged, because browser GPUs do not match the reference renderer

### Requirement: Reproducible runs
Two runs of the same scenario with the same seed on the same platform SHALL produce identical
rendered frames.

#### Scenario: Running a scenario twice
- **WHEN** the boot scenario is run twice with `--seed 7`
- **THEN** the final frames of both runs are identical pixel for pixel

### Requirement: Emulated input in scenarios
Scenarios SHALL be able to press and release keys and mouse buttons, set gamepad axes and buttons, and
put down, move and lift touches. Emulated input SHALL take the same path as real device events, so the
game cannot tell the difference, and it SHALL work with and without rendering.

#### Scenario: Holding a key in a scenario
- **WHEN** a scenario calls `t.key("D", true)` and then waits a frame
- **THEN** `fk.input.key("D")` is true and the last used device is "keyboard"

#### Scenario: Touch in a scenario
- **WHEN** a scenario calls `t.touch(1, 0.25, 0.75)` and then `t.touch(1)`
- **THEN** the game sees a touch at (0.25, 0.75) that is lifted again
