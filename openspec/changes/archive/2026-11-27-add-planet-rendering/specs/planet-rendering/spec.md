## Purpose

Draws planets from space as detailed cube spheres with a quadtree of chunks built in the background, rings, and no
holes, within budgets.

## ADDED Requirements

### Requirement: Planet chunks and detail
A planet SHALL be drawn as chunks of a cube sphere whose detail follows the screen: a chunk splits where its grid
would span more than 3 internal pixels; chunks behind the horizon are not drawn; a chunk is drawn until all four of its
children are built; chunks are built in the background and dropped when unused. There SHALL be no holes between
chunks of different detail.

#### Scenario: Closer means more detail
- **WHEN** the camera moves from 20 radii to 1.05 radii from a planet
- **THEN** more chunks are drawn

#### Scenario: No holes
- **WHEN** planets are drawn from orbit
- **THEN** no pixels of space show through their surfaces

### Requirement: Rings
Ring systems SHALL be drawn as bands between their inner and outer radii with gaps, lit on the side facing the star.

#### Scenario: A ringed giant
- **WHEN** a ringed gas giant is drawn from five radii
- **THEN** its rings show around it, matching the reference image

### Requirement: Budgets
Each planet from orbit SHALL take at most 400 draws and 700,000 triangles.

#### Scenario: Every kind
- **WHEN** a planet of each kind is drawn from orbit
- **THEN** it stays within budget and matches its reference image
