# navigation-maps Specification

## Purpose

Puts the range in the generated universe: the current star and world are simulation state, the sky and light over
the range come from them, and the galaxy and system maps let the Commander look around and jump to another star.

## Requirements

### Requirement: The universe over the range
A new game SHALL start on a terran or ocean world of the nearest Sun-like star that has one. The range SHALL be lit
by its star, turning with the world's day so that night falls; its sky SHALL take its colour from the world's air (black
without air); the stars of the galaxy SHALL show at night and always on worlds without air; the system's other bodies
and stars SHALL hang in the sky where they are; gravity SHALL be the world's surface gravity.

#### Scenario: Night falls
- **WHEN** the simulation time runs on over the home world
- **THEN** the star sets, its light goes out, and the star map shows at full strength

### Requirement: Galaxy and system maps
M, Y or the MAP button SHALL open the galaxy map: the real stars within 30 ly from above, the 20 ly jump range,
unusual signatures, and the chosen system's name, star, distance, archetype, planet count and signature. Tab SHALL
switch to the system map: orbits on a logarithmic scale, the bodies where they are, a time scrubber, and the chosen
body's class, temperature, gravity, air and marvels. While a map is open the suit SHALL hold still.

#### Scenario: Opening the maps
- **WHEN** the Commander presses M and then Tab
- **THEN** the galaxy map and then the system map show, matching their reference images

### Requirement: Jumping
Enter on a star within range SHALL send a jump command; the simulation SHALL move the range to that star's most
welcoming world, with its gravity; the presentation SHALL play the jump sequence (streaks, a flash, shake, rumble, a
roar). Stars out of range and the current star SHALL be refused.

#### Scenario: Three jumps
- **WHEN** the Commander jumps three times from the galaxy map
- **THEN** the range reaches three new systems, each arrival matches its reference image, and the state hash matches
  the recorded one on every platform
