# Spec Delta

## ADDED Requirements

### Requirement: Rumble
Scripts SHALL rumble the open gamepads with a low- and a high-frequency strength for a duration; on a phone
browser after touch input, strong rumbles SHALL vibrate the phone instead.

#### Scenario: Gamepad rumble
- **WHEN** a script asks for a rumble of 0.5, 0.5 for 0.1 s with a gamepad connected
- **THEN** the gamepad's motors run for 0.1 s
