# Spec Delta

## ADDED Requirements

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
