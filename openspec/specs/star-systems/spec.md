# star-systems Specification

## Purpose

Generates the system of any galaxy star from its seed: stars, planets, moons, rings, belts, comets and disks on
Kepler orbits, plausible and stable, as plain data that is the same on every platform.

## Requirements

### Requirement: System archetypes
A system SHALL be one of the archetypes its star allows: single star, close binary with circumbinary planets, wide
binary, hierarchical triple, star with a brown dwarf, white dwarf with a debris disk, pulsar with irradiated worlds,
black hole with an accretion disk, young star with a protoplanetary disk, red giant, or rogue planet with no star.
Archetypes SHALL be a registry that mods can extend.

#### Scenario: All of them
- **WHEN** 10,000 systems are generated from stars near the Sun's circle
- **THEN** every archetype appears

### Requirement: Stable, plausible orbits
Planets SHALL be at least 2√3 mutual Hill radii apart from periapsis to apoapsis; moons SHALL stay within half their
planet's Hill sphere and clear of its surface; rings SHALL lie inside the Roche zone and clear of every moon. Giants
SHALL form mostly beyond the frost line, and the habitable zone and frost line SHALL follow the star's luminosity.

#### Scenario: No unstable orbits
- **WHEN** 10,000 systems are generated and checked
- **THEN** no system breaks a rule

### Requirement: Planet classes
Each planet and moon SHALL get a class from its physical facts (mass, temperature, water, iron, carbon, tidal
locking): lava, iron, barren, desert, terran, ocean, ice, glacier, carbon, super-Earth, mini-Neptune, ice giant, gas
giant, hot Jupiter, eyeball or shattered, with an albedo and an atmosphere. Classes SHALL be a registry.

#### Scenario: Every class
- **WHEN** 10,000 systems are generated
- **THEN** every class appears at least once

### Requirement: Deterministic descriptors
A system SHALL be plain data generated from its star's seed alone, the same on every platform.

#### Scenario: Same systems everywhere
- **WHEN** the first 200 of the 10,000 systems are encoded and hashed on Linux, Windows, macOS or in the browser
- **THEN** the hash matches the recorded one
