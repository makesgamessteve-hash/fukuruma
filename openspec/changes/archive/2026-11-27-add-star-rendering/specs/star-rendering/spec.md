## Purpose

Draws stars, pulsars and neighbouring worlds in the sky, and lights worlds by both stars of a binary.

## ADDED Requirements

### Requirement: Stars
The renderer SHALL draw a star as an emissive sphere of its black-body colour whose surface shows convection cells and
spots, glowing through bloom; a pulsar SHALL also show a beam sweeping round with its period.

#### Scenario: Kinds of star
- **WHEN** a Sun-like star, a red dwarf, a blue giant and a pulsar are seen from space
- **THEN** each shows its colour and glow, the pulsar its beam, matching the reference images

### Requirement: Binary light
A world in a binary system SHALL be lit by both stars, each with its own colour and direction.

#### Scenario: Two suns
- **WHEN** a planet is lit by a warm and a blue star from opposite sides
- **THEN** each side takes that star's colour, matching the reference image

### Requirement: Worlds in the sky
Neighbouring bodies that span more than a few pixels SHALL be drawn with their real surfaces, tilted and turning with
their day; smaller ones SHALL be drawn as simple spheres of their class colour.

#### Scenario: A neighbour through a long lens
- **WHEN** the sky is drawn with a narrow field of view
- **THEN** neighbouring worlds are drawn as planet surfaces
