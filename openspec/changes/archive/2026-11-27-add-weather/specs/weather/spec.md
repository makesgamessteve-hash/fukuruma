## Purpose

Brings the weather to a world with air: spells of rain, storms, snow and sandstorms, and how each one looks and sounds.

## ADDED Requirements

### Requirement: Spells of weather
A world with air SHALL have weather in spells. The kind of each spell SHALL depend only on the world's seed and the
time, and SHALL be one the world can have:
- rain and storms on worlds with oceans;
- snow on cold worlds;
- sandstorms on dry worlds.

Each spell SHALL rise and fall smoothly. A world without air SHALL stay clear.

#### Scenario: Same world, same weather
- **WHEN** the weather of the same world is asked for twice at the same time
- **THEN** both answers have the same kind and strength

#### Scenario: A spell's course
- **WHEN** a rain spell is sampled near its start, at its middle and near its end
- **THEN** its strength is low, then full, then low again

### Requirement: Showing the weather
The weather SHALL show without changing the simulation. Each kind SHALL have its own:
- falling particles around the eye: rain as streaks, snow as flakes, sand blowing sideways;
- extra cloud cover and fog;
- ground layers: wet, snow or dust;
- a looping sound.

Falling particles SHALL stay within the particle budget.

#### Scenario: Rain, snow, sandstorm and storm
- **WHEN** each kind falls around the eye for a moment
- **THEN** the picture matches its reference image

### Requirement: Lightning
Storms SHALL throw lightning now and then. A strike SHALL be a flash of light, followed by thunder after the time sound
takes to travel from it.

#### Scenario: A strike
- **WHEN** a storm at full strength strikes
- **THEN** the flash shows, the thunder plays once its delay has passed, and the picture matches its reference image
