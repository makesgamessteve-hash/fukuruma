## Purpose

Streams a world's ground from orbit down to the suit's feet, without holes and within budget, and lets bodies and the
suit stand and walk on it.

## ADDED Requirements

### Requirement: Seamless descent
The renderer SHALL draw a world's surface continuously from orbit to standing height: chunks refine with distance down
to sub-metre quads, chunks of different levels and depth slices meet without holes, and the frame stays within the
draw and triangle budget.

#### Scenario: From orbit to the ground
- **WHEN** the camera descends from 2000 km to 2 m above a site on land
- **THEN** every stop shows unbroken ground within 700 draws and 1.6 million triangles, matching the reference images

### Requirement: Standing on the ground
The physics world SHALL hold a terrain heightfield of the world's real surface around the suit, and bodies and
characters SHALL collide with it; the terrain SHALL be rebuilt deterministically from the world and the suit's position.

#### Scenario: Off the deck
- **WHEN** the suit walks off the deck
- **THEN** it walks on the world's ground at the ground's height

#### Scenario: Save and load
- **WHEN** a game is saved on the ground, loaded in a new session and continued with the same inputs
- **THEN** the state hash matches the uninterrupted run

### Requirement: A site on land
The range SHALL stand on a levelled site on land when its world has land, keeping the star where it stands on arrival.

#### Scenario: An ocean world with islands
- **WHEN** a new game starts on an ocean world
- **THEN** the site lies on an island, level with the deck

### Requirement: Terrain detail scales
The terrain's detail SHALL follow the graphics level (coarser quads at lower levels).

#### Scenario: Software renderer
- **WHEN** the game runs on a software renderer
- **THEN** it starts on Low with coarse terrain quads
