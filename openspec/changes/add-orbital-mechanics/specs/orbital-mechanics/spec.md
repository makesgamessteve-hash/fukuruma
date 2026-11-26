## Purpose

Moves planets, moons, stations and parked vessels on Kepler orbits on rails, with trigonometry that gives the same
bits on every platform, so their positions are reproducible.

## ADDED Requirements

### Requirement: Deterministic trigonometry
The engine SHALL provide sine and cosine that give the same bits on every platform and are within about 1 ulp of
the exact values for arguments up to 1e6.

#### Scenario: Recorded bits
- **WHEN** the sine of 1.0 is computed on Linux, Windows, macOS or in the browser
- **THEN** it is the double 0x3feaed548f090cee

### Requirement: Kepler orbits
Scripts SHALL get the position and velocity of a body on an elliptic orbit at any time from its elements (semi-major
axis, eccentricity, inclination, ascending node, argument of periapsis, mean anomaly at an epoch, gravitational
parameter), relative to the central body, with x-z as the reference plane and +y as north. Invalid elements SHALL
be a script error.

#### Scenario: Circular orbit
- **WHEN** a body on a circular orbit with an inclination of 0 is placed at time 0 and a quarter period later
- **THEN** it is first on +x and then on -z at the orbit's radius, moving counter-clockwise seen from +y

#### Scenario: Energy
- **WHEN** a body on an eccentric, inclined orbit is placed at many times
- **THEN** its speed and distance always satisfy the vis-viva equation

### Requirement: Motion on rails
Frames SHALL follow Kepler orbits around their parent and turn about an axis at a fixed rate, placed from the
simulation time alone, so their positions are reproducible on every platform.

#### Scenario: One orbit later
- **WHEN** the scale ladder's ship is placed after one orbital period
- **THEN** it is back where it started to within 1 mm

#### Scenario: Same everywhere
- **WHEN** the orbits scenario places the bodies a year after the start
- **THEN** the state hash matches the recorded one on every platform
