## MODIFIED Requirements

### Requirement: Touch controls
When the last input came from touch, the game SHALL show a virtual stick (where the left half of the
screen is first touched) and its touch buttons (on the right), and SHALL hide them after keyboard,
mouse or gamepad input. Stick displacement up to 12% of the screen height maps to -1..1 on each axis.
The first finger that lands on the right half of the screen and not on a button SHALL be the look finger;
its movement since the last frame SHALL be available to scripts.

#### Scenario: Thumb on the left half
- **WHEN** a finger touches the left half of the screen and moves right by 12% of the screen height
- **THEN** the stick's horizontal axis is 1 and the stick is drawn under the finger

#### Scenario: Back to the keyboard
- **WHEN** a key is pressed after a touch
- **THEN** the touch controls are no longer drawn

#### Scenario: Look finger
- **WHEN** a finger lands on the right half of the screen, away from the buttons, and moves right by 5% of the width
- **THEN** the look movement of that frame is 0.05 across

## ADDED Requirements

### Requirement: Looking
The mouse, the right stick and the look finger SHALL turn the view; moving across the whole width with the mouse
SHALL turn it by 3 radians. Scripts SHALL be able to capture the mouse (relative mode, pointer lock in browsers);
the sandbox captures it while no menu is open and the last input was not touch.

#### Scenario: Mouse to the left
- **WHEN** the mouse moves left by half the window's width with the mouse captured
- **THEN** the view turns 1.5 radians to the left
