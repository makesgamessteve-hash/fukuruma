# Spec Delta

## Purpose

Draws pixel text and simple widgets on the internal image and makes menus usable with keyboard,
gamepad, mouse and touch, for settings now and HUDs and cockpit screens later.

## ADDED Requirements

### Requirement: Pixel text and rectangles
Scripts SHALL be able to draw text with an 8×8 pixel font and filled, optionally translucent rectangles
at whole-pixel positions of the internal image, on top of the scene and in the order drawn. Text SHALL
support the printable ASCII characters; others SHALL be drawn as "?".

#### Scenario: Crisp text
- **WHEN** a script draws "FUKURUMA" at (8, 8) in white
- **THEN** the glyphs appear unscaled and unfiltered, each 8×8 internal pixels

#### Scenario: Unsupported characters
- **WHEN** a script draws "Grüße"
- **THEN** the non-ASCII characters appear as "?"

### Requirement: Menu navigation
Menus SHALL be navigable with the arrow keys or W/S/A/D plus Enter and Escape, the gamepad's d-pad or
left stick plus A and B, the mouse (hover and click) and touch (tap). Moving past the last item SHALL
wrap to the first. Left and right (or tapping the value's halves) SHALL change an option's value.

#### Scenario: Wrapping
- **WHEN** the last item is focused and the player presses Down
- **THEN** the first item is focused

#### Scenario: Tapping an option
- **WHEN** the player taps the right half of an option's value
- **THEN** the option moves to its next value
