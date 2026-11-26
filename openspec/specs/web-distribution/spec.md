# web-distribution Specification

## Purpose

Defines the browser build of the game and its publication on GitHub Pages, so that the current
state of `main` can always be played at one public address.

## Requirements

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

### Requirement: Publication on GitHub Pages
Every push to `main` for which all CI jobs pass SHALL publish the web build at
`https://makesgamessteve-hash.github.io/fukuruma/`. A push with any failing CI job SHALL leave the
previous publication unchanged.

#### Scenario: Green push
- **WHEN** a commit is pushed to `main` and every CI job passes
- **THEN** the page at the Pages address serves the web build of that commit

#### Scenario: Red push
- **WHEN** a commit is pushed to `main` and a CI job fails
- **THEN** the page keeps serving the last build that passed

### Requirement: Link in the README
The first content line of `README.md` SHALL be a link to the Pages address.

#### Scenario: Reading the README
- **WHEN** the repository's README is viewed on GitHub
- **THEN** the link to the playable web build appears above all other content except the title

### Requirement: Unsupported browsers
When WebGL 2 is not available, the page SHALL show a readable message that names the requirement,
instead of an empty canvas.

#### Scenario: Browser without WebGL 2
- **WHEN** the page is opened in a browser where WebGL 2 cannot be created
- **THEN** the page shows a message saying that WebGL 2 is required

### Requirement: Scenarios in the browser
The page SHALL accept a `scenario` query parameter that runs a game-test scenario from the data
package and exposes its result (passed or failed, with the message) to the page's scripts, so
browser tests can run the same scenarios as desktop CI.

#### Scenario: Boot scenario in the browser
- **WHEN** the page is opened with `?scenario=boot`
- **THEN** the boot scenario runs and its result reads "passed" from page script
