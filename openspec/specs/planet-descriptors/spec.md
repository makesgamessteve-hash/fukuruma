# planet-descriptors Specification

## Purpose

Turns a generated body into the description of a world: relief, oceans, colours by field and biome, air optics,
clouds and grading, from its class and seed.

## Requirements

### Requirement: Recipes per class
Every planet class SHALL have a recipe (a noise graph, relief, sea level, ocean, life and a palette) in a registry
that mods can extend; an unknown class SHALL look barren. The same body SHALL give the same world.

#### Scenario: Every class
- **WHEN** a body of each class is described
- **THEN** each has a surface whose heights stay within its relief

### Requirement: Fields and biomes
A surface's colour SHALL follow its fields: oceans by depth, beaches, land by height, vegetation by temperature and
moisture on living worlds, peaks, frozen seas and polar ice where it is cold; giants SHALL show turbulent latitude bands.

#### Scenario: Cold poles
- **WHEN** the pole of a terran world at 200 K is sampled
- **THEN** its colour is ice

### Requirement: Air optics
A body with air SHALL get scattering and absorption coefficients from its gas, scaled by its pressure (capped at 50
bar), a scale height and the top of its air.

#### Scenario: Deep air
- **WHEN** a desert world with 90 bar of sulphurous air is described
- **THEN** its Mie scattering is the gas's value at 50 bar
