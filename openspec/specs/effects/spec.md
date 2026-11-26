# effects Specification

## Purpose

Makes actions feel physical: particles, light flashes, camera shake, hit-pause, rumble and camera rigs,
driven by simulation and animation events from a feedback table, scaled by comfort settings. Effects are
presentation and never change the simulation.

## Requirements

### Requirement: Particles
Scripts SHALL emit bursts of presentation particles with a cone or a ring of velocities, a birth radius,
speed, life, size, colour and alpha over life, gravity and drag, as lit dust or as glowing light. Particles
SHALL be hidden behind scene surfaces and fade where they meet them. The number alive SHALL stay within the
detail level's budget, the oldest making room for new ones.

#### Scenario: Footstep dust
- **WHEN** the Exosuit walks
- **THEN** a puff of dust rises where each foot lands

#### Scenario: Budget
- **WHEN** more particles are emitted than the budget allows
- **THEN** the oldest particles disappear first

### Requirement: Feedback bundles
The game SHALL map events to bundles of particles, a light flash, camera trauma, hit-pause, rumble and a
sound in a data table, play the bundle of every simulation event that has one, and scale a bundle by a
strength.

#### Scenario: Scan pulse
- **WHEN** the player presses the scan button
- **THEN** a ring of light spreads over the ground from the suit, a cyan light flashes, the camera shakes
  and the gamepad rumbles

### Requirement: Camera shake
Events SHALL add trauma that falls off with the distance from the camera's doll and with that doll's mass and
decays over time; the camera SHALL shake by the square of the trauma.

#### Scenario: Distance
- **WHEN** the same event happens 5 m and 35 m from the camera's doll
- **THEN** the far one adds half the trauma of the near one

### Requirement: Hit-pause
A bundle MAY hold presentation time for a fraction of a second; animation and particles SHALL stop for that
long while the simulation keeps running.

#### Scenario: Short pause
- **WHEN** a bundle with a 0.1 s hit-pause plays
- **THEN** presentation time stands still for 0.1 s and then runs on

### Requirement: Camera rigs
The game SHALL have a chase camera that follows its target on springs, lags more for heavier dolls and looks
ahead of a moving target, and a first-person camera at a node of a model.

#### Scenario: Looking ahead
- **WHEN** the target keeps moving at 5 m/s with a look-ahead of 0.5 s
- **THEN** the camera aims 2.5 m ahead of it

### Requirement: Tweens
Scripts SHALL have tweens that move a value over a duration with an easing curve.

#### Scenario: Menu pop-in
- **WHEN** the settings menu opens
- **THEN** it drops in and settles with a slight overshoot within a quarter of a second

### Requirement: Comfort settings
The settings menu SHALL offer camera shake and light flashes at 100%, 50% or off, and rumble on or off; the
effects SHALL follow them and the choices SHALL be stored.

#### Scenario: Shake off
- **WHEN** camera shake is set to off and an event adds trauma
- **THEN** the camera does not move
