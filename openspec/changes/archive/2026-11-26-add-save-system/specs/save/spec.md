# Spec Delta

## Purpose

Keeps the player's game: the world seed and the simulation state as versioned, readable text in save slots on every
platform, safe to share because loading never runs code.

## ADDED Requirements

### Requirement: Save and load
The game SHALL save the world seed and the complete simulation state into a slot and load it back so that the state
hash equals the hash at saving and the game continues exactly as it would have.

#### Scenario: Quick save round trip
- **WHEN** the player saves with F5 after walking, walks on, and loads with F9
- **THEN** the Exosuit is back at the saved position, the state hash equals the saved one, and walking continues from there

#### Scenario: No save yet
- **WHEN** the player loads before saving
- **THEN** the game says there is no saved game and nothing changes

### Requirement: Save format
Saves SHALL be Lua-table text with a header, holding only tables, strings, numbers and booleans; integers and floats
SHALL keep their type and every number its exact value. Loading SHALL parse the text and SHALL NOT execute it;
anything else SHALL be refused with the line and the problem.

#### Scenario: A save with code
- **WHEN** a save file contains `return os.exit()`
- **THEN** loading fails with "a value expected" and nothing runs

### Requirement: Versions
Saves SHALL carry a format version. Older versions SHALL be migrated step by step on loading; saves from a newer game
version SHALL be refused with a message.

#### Scenario: A newer save
- **WHEN** a save of version 2 is loaded by a game that knows version 1
- **THEN** loading fails with "made by a newer version of the game"

### Requirement: Save slots
Saves SHALL live in named slots (lowercase letters, digits and underscores) stored through the game's storage:
the user's application-data folder on desktop and IndexedDB in browsers.

#### Scenario: Browser reload
- **WHEN** the player saves in the browser, reloads the page and loads
- **THEN** the saved game is back
