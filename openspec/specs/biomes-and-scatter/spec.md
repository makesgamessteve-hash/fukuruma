# biomes-and-scatter Specification

## Purpose

Covers the ground near the eye with flora and rocks that follow its biome and sway in the wind.

## Requirements

### Requirement: Plants follow the ground
Grass, shrubs and trees SHALL grow on green ground and rocks SHALL lie on steep, dry and frozen ground, from the
ground's own colour and slope; nothing SHALL grow on the deck.

#### Scenario: Three biomes
- **WHEN** the ground is seen from standing height on a meadow, a dry hillside and frozen ground
- **THEN** each shows its own plants and stones within the frame budget, matching the reference images

### Requirement: The same place looks the same
Plants SHALL be placed from a hash of their cell, so a place always gets the same plants.

#### Scenario: Built twice
- **WHEN** the plants of the same grid are built twice
- **THEN** they are identical

### Requirement: Wind
Plants SHALL sway in the wind, more at their tips, with gusts.

#### Scenario: A moment later
- **WHEN** the meadow is drawn again 1.3 seconds later
- **THEN** the grass and shrubs lean differently, matching the reference image

### Requirement: Plants scale
The number of plants SHALL follow the graphics level.

#### Scenario: A lower level
- **WHEN** a lower level draws the same grid
- **THEN** it holds fewer plants
