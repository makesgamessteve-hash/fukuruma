# webxr Specification

## Purpose

Playing in VR in the browser: the immersive session, both eyes, the head as the Commander's head, and the controllers.

## Requirements

### Requirement: Stereo
The renderer SHALL draw both eyes side by side, each from its own position half the distance between the eyes to its
side.

#### Scenario: The stereo debug view
- **WHEN** stereo is on, looking from the range towards the Walker
- **THEN** both eyes' views appear side by side, matching the reference image

### Requirement: The headset
Where the browser offers immersive VR, the game SHALL offer to enter VR. In a session it SHALL render in stereo, and the
head's rotation SHALL turn the Commander's view. Ending the session SHALL restore the page.

#### Scenario: A mocked headset in the browser
- **WHEN** a page with a headset available is opened, ENTER VR is clicked, and the session later ends
- **THEN** the session runs the game's frames without errors, and ENTER VR is offered again

#### Scenario: The head turns the view
- **WHEN** the headset reports the head turned 90 degrees to the left
- **THEN** the Commander's view has turned 90 degrees to the left, in stereo

### Requirement: Controllers
The headset's controllers SHALL play like a gamepad (the left stick moves, the right stick looks, buttons for the
actions), and rumble SHALL pulse their haptics.

#### Scenario: Walking and scanning with the controllers
- **WHEN** the left stick is pushed forward and right A is pressed
- **THEN** the suit walks and scans
