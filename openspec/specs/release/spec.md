# release Specification

## Purpose

Shipping the game: saves that keep loading, release packages per platform and the press kit.

## Requirements

### Requirement: Save compatibility
A game saved by release 1.0 SHALL load in every later version, migrated where the format changed. Saves from older
development versions SHALL be refused with a message that says so.

#### Scenario: The 1.0 fixture
- **WHEN** the test loads the save written by release 1.0
- **THEN** the Commander, the samples and the goods are as saved, and the game plays on

### Requirement: Release packages
A version tag SHALL produce a zip per desktop platform with the game, its data, its mods, the licences and the
notices, attached to the tag's GitHub Release.

#### Scenario: Tagging v1.0.0
- **WHEN** v1.0.0 is pushed
- **THEN** the Release has zips for Windows, Linux and macOS

### Requirement: Press kit
Pages SHALL host a press kit page next to the game, with facts, features and screenshots.

#### Scenario: The site
- **WHEN** a build is deployed
- **THEN** presskit.html and its screenshots are published with it
