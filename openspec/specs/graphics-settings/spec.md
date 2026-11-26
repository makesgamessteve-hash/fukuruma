# graphics-settings Specification

## Purpose

Lets players choose how much the GPU does through named detail levels and individual options in an
in-game menu, applied live and remembered, with sensible defaults per device.

## Requirements

### Requirement: Detail levels
The game SHALL offer the detail levels Low, Medium, High and Ultra, and Custom. The levels SHALL differ
in shadows, ambient occlusion, point lights and anti-aliasing; every level SHALL render the same models.
Custom SHALL start from the current level and let each of those options be changed on its own.

#### Scenario: Low and Ultra
- **WHEN** the level is Low
- **THEN** there is one shadow cascade, no ambient occlusion and no anti-aliasing
- **AND WHEN** the level is Ultra
- **THEN** there are four shadow cascades, 16 ambient-occlusion samples and 2×2 supersampling

#### Scenario: Custom keeps the rest
- **WHEN** the level is High and the player sets shadows to 1 cascade
- **THEN** the level becomes Custom and every other option keeps its High value

### Requirement: Graphics menu
The game SHALL open a graphics menu with Escape, the gamepad's Start button or a touch button. The menu
SHALL show the detail level, resolution (Classic 480×270, Sharp 640×360, Fine 960×540), fill the window,
anti-aliasing, dithering, palette mode and the Custom options. A change SHALL take effect within a frame
while the scene keeps running behind the menu. Closing the menu SHALL return control to the game.

#### Scenario: Switching the level from the menu
- **WHEN** the player opens the menu, selects the detail level and changes it from High to Low
- **THEN** the next frame is rendered with the Low settings and the scene is still moving

#### Scenario: Game controls pause while the menu is open
- **WHEN** the menu is open and the player presses D
- **THEN** the ship does not turn

### Requirement: Device defaults
On the first start, when no settings are stored, the game SHALL choose Low for software renderers and
phones, Medium for browsers on desktops and laptops, and High otherwise.

#### Scenario: Software renderer
- **WHEN** the game starts for the first time with a software OpenGL renderer
- **THEN** the detail level is Low

### Requirement: Saved settings
Graphics settings SHALL be saved when changed and restored on the next start.

#### Scenario: Restart
- **WHEN** the player chooses Ultra and restarts the game
- **THEN** the game starts with Ultra
