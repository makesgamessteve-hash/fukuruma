# input Specification

## Purpose

Turns keyboards, mice, gamepads and touch screens into named game actions with changeable bindings, and
shows touch controls on touch devices, so every doll can be controlled on every platform.

## Requirements

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

### Requirement: Last used device
The engine SHALL report which kind of device produced the latest input: "keyboard", "mouse", "gamepad" or "touch".

#### Scenario: Switching devices
- **WHEN** the screen is touched and then a key is pressed
- **THEN** the device is "touch" after the touch and "keyboard" after the key

### Requirement: Actions
Games SHALL define named actions of two kinds. An axis action has a value from -1 to 1 combined from
negative and positive keys, a gamepad axis with a dead zone of 0.2, and a touch-stick axis; the input
with the largest magnitude wins. A button action is held while any of its keys, gamepad buttons or touch
buttons is held, and reports a press only in the frame it went down.

#### Scenario: Keys make an axis
- **GIVEN** an axis action with negative key "A" and positive key "D"
- **WHEN** D is held
- **THEN** the action's value is 1

#### Scenario: Dead zone
- **WHEN** the bound gamepad axis reads 0.1
- **THEN** the action's value is 0

#### Scenario: Press edge
- **WHEN** a bound key goes down and stays down for three frames
- **THEN** the button action reports a press in the first frame only, and is held in all three

### Requirement: Remapping
Games SHALL be able to change an action's bindings at runtime; the new binding takes effect in the next frame.

#### Scenario: Rebinding a key
- **WHEN** the game binds "turn" to the keys J and L instead of A and D
- **THEN** L turns the ship and D no longer does

### Requirement: Touch controls
When the last input came from touch, the game SHALL show a virtual stick (where the left half of the
screen is first touched) and its touch buttons (on the right), and SHALL hide them after keyboard,
mouse or gamepad input. Stick displacement up to 12% of the screen height maps to -1..1 on each axis.

#### Scenario: Thumb on the left half
- **WHEN** a finger touches the left half of the screen and moves right by 12% of the screen height
- **THEN** the stick's horizontal axis is 1 and the stick is drawn under the finger

#### Scenario: Back to the keyboard
- **WHEN** a key is pressed after a touch
- **THEN** the touch controls are no longer drawn

### Requirement: Quick presses
A key, mouse button, gamepad button or touch that is pressed and released between two frames SHALL read
as held for one frame, so short taps are not lost when frames are slow.

#### Scenario: Quick tap
- **WHEN** a finger touches the screen and lifts again before the next frame
- **THEN** the next frame lists the touch, and the frame after it does not

#### Scenario: Pressed again
- **WHEN** a key is pressed, released and pressed again before the next frame
- **THEN** it reads as held in the next frame and stays held until it is released

### Requirement: Rumble
Scripts SHALL rumble the open gamepads with a low- and a high-frequency strength for a duration; on a phone
browser after touch input, strong rumbles SHALL vibrate the phone instead.

#### Scenario: Gamepad rumble
- **WHEN** a script asks for a rumble of 0.5, 0.5 for 0.1 s with a gamepad connected
- **THEN** the gamepad's motors run for 0.1 s
