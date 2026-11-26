# Spec Delta

## ADDED Requirements

### Requirement: Quick presses
A key, mouse button, gamepad button or touch that is pressed and released between two frames SHALL read
as held for one frame, so short taps are not lost when frames are slow.

#### Scenario: Quick tap
- **WHEN** a finger touches the screen and lifts again before the next frame
- **THEN** the next frame lists the touch, and the frame after it does not

#### Scenario: Pressed again
- **WHEN** a key is pressed, released and pressed again before the next frame
- **THEN** it reads as held in the next frame and stays held until it is released
