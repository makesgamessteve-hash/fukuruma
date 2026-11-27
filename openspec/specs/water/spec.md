# water Specification

## Purpose

Draws a world's sea up close: its surface from above, the floor through it, and the world from below it.

## Requirements

### Requirement: The sea's surface
Where the view meets the sea before anything else, the renderer SHALL show its surface with moving waves, the sky and
the star reflected more at grazing angles, the floor refracted and dimmed by the depth of water, and foam where it is
shallow.

#### Scenario: The waterline and the open sea
- **WHEN** the sea is seen from the waterline, towards the low star, and from above the shallows
- **THEN** it shows its reflections, glint and waves, matching the reference images

### Requirement: Under the sea
From under the surface the world SHALL be seen through water, and the sea floor SHALL show caustics.

#### Scenario: Diving
- **WHEN** the camera is a few metres under the surface
- **THEN** the floor fades into the water's colour, matching the reference image

### Requirement: Sea floors
Oceans SHALL have floors that the suit can walk on under the water.

#### Scenario: Below sea level
- **WHEN** the ground's height is sampled under an ocean
- **THEN** it lies below sea level
