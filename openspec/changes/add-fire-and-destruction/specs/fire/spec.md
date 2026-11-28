## ADDED Requirements

### Requirement: Spreading fire
Fire SHALL spread from burning cells to their neighbours, more readily the drier the vegetation, and the same way
every time. Burnt cells SHALL NOT burn again.

#### Scenario: A fire in dry plants
- **WHEN** a cell is lit on a dry world
- **THEN** the fire spreads to its neighbours and the burnt cells become ash

### Requirement: Explosions
A gas pocket reached by fire SHALL explode, hurting the suit and knocking down creatures nearby.

#### Scenario: Gas in the fire's way
- **WHEN** fire reaches a gas pocket
- **THEN** the pocket explodes and is gone
