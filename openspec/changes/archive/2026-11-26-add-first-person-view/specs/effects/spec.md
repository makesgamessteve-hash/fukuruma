## MODIFIED Requirements

### Requirement: Comfort settings
The settings menu SHALL offer camera shake and light flashes at 100%, 50% or off, rumble on or off, head bob at
100%, 50% or off, a field of view of 70, 80, 90 or 60 degrees, and the turning vignette on or off; the effects SHALL
follow them and the choices SHALL be stored.

#### Scenario: Shake off
- **WHEN** camera shake is set to off and an event adds trauma
- **THEN** the camera does not move

#### Scenario: Head bob off
- **WHEN** head bob is off and the Exosuit runs
- **THEN** the eye stays at the head's rest height

## ADDED Requirements

### Requirement: Helmet and drone rigs
The game SHALL have a helmet rig that looks from an eye position with a yaw and a pitch (the pitch clamped), reports
how fast it turns and gives the flat forward and right directions for walking, and an orbit rig that circles a
target at a distance, never below the ground. There SHALL be no camera that follows the player from outside while
the player moves.

#### Scenario: Looking right
- **WHEN** the helmet looks a quarter turn to the right from +z
- **THEN** its forward direction is -x

#### Scenario: Drone above the ground
- **WHEN** the orbit rig is asked to look further down than the ground
- **THEN** its pitch stops just above the horizon

### Requirement: First-person view
The game SHALL be seen through the Commander's eyes inside the Exosuit: the camera sits at the eyes in the animated
head, the head is not drawn from inside, walking goes where the Commander looks, and the suit turns to face that way.

#### Scenario: Walking where the Commander looks
- **WHEN** the Commander turns the view a quarter turn to the left and walks forward
- **THEN** the Exosuit walks along +x and faces +x

### Requirement: Outside view
V, the gamepad's Back button or the touch button VIEW SHALL switch to the survey drone's outside view, which starts
behind the Commander and orbits the suit when looking. While it is open the suit SHALL hold still and SHALL not scan;
the same input SHALL return to the Commander's eyes.

#### Scenario: View only
- **WHEN** the outside view is open and W and E are held
- **THEN** the Exosuit does not move and no scan starts

### Requirement: Visor HUD
The helmet view SHALL show a compass with the heading in degrees, the speed, the scanner's charge, the visor's frame
and, when the turning vignette is on and the view turns faster than 1.5 rad/s, a vignette. The outside view SHALL
show a drone feed with scanlines and a note that it is for viewing only.

#### Scenario: Heading east
- **WHEN** the Commander looks along -x
- **THEN** the compass shows 090

## REMOVED Requirements

### Requirement: Camera rigs
**Reason**: The game is seen through the Commander's eyes; the chase camera and the first-person camera at a node
are replaced by the helmet and drone rigs.
**Migration**: Use `camera.helmet` for the player's view and `camera.orbit` for the outside view.
