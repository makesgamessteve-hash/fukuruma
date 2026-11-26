# Spec Delta

## MODIFIED Requirements

### Requirement: Browser build
The game SHALL build for browsers with WebGL 2 and run the same `data/scripts/main.lua` as the
desktop builds. The game view SHALL cover the whole browser window, so the renderer decides between
filling it and black bars, as in a desktop window.

#### Scenario: Opening the page in a WebGL 2 browser
- **WHEN** the published page is opened in a desktop browser with WebGL 2
- **THEN** the game starts and renders the same placeholder scene as the desktop build

#### Scenario: Phone in landscape
- **WHEN** the page is opened on a phone held sideways with "Fill window" on
- **THEN** the game image covers the whole screen without black bars

#### Scenario: Changing settings while playing
- **WHEN** a graphics setting is changed in the menu
- **THEN** the page keeps showing new frames rendered with the new setting
