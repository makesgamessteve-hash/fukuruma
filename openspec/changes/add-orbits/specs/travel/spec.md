## ADDED Requirements

### Requirement: Orbits
Stations and the Jump Ship SHALL go round their world at the speed their height needs, whether the Commander is aboard
or not. Flying dolls on autopilot SHALL reach a doll in orbit wherever it is in its orbit, including the far side of
the world.

#### Scenario: The station goes round
- **WHEN** time passes
- **THEN** the station has moved along its orbit at the same distance from the world's centre

#### Scenario: Catching the station on the far side
- **WHEN** in the Fukuruma test the Drop Ship flies back up while the station is round the far side of the world
- **THEN** it reaches the station, and the test passes
