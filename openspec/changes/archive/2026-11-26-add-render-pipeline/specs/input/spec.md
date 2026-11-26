# Spec Delta

## MODIFIED Requirements

### Requirement: Raw input state
Scripts SHALL be able to read, at any time during a frame, whether a key (by its SDL name, such as "W"
or "Space") or a mouse button is held, the mouse position and its movement in this frame, the axes
(-1 to 1, triggers 0 to 1) and buttons of the connected gamepads, and the active touches. Mouse and
touch positions SHALL be normalised to 0..1 across the game image (outside the black bars).

#### Scenario: Key held
- **WHEN** the D key is pressed and not yet released
- **THEN** `fk.input.key("D")` is true, and it is false after the release

#### Scenario: Touch positions
- **WHEN** a finger touches the centre of the window
- **THEN** `fk.input.touches()` lists one touch at about (0.5, 0.5)

#### Scenario: Touch beside the image
- **WHEN** the image has black bars on the left and right and a finger touches the left edge of the image
- **THEN** the touch's x is about 0

#### Scenario: Unknown names
- **WHEN** a script asks for a key or gamepad control name that does not exist
- **THEN** a script error names it
