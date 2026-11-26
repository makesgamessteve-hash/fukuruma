# reference-frames Specification

## Purpose

TBD - created by archiving change add-reference-frames. Update Purpose after archive.

## Requirements

### Requirement: Frame tree
The game SHALL place things in a tree of reference frames. A frame SHALL have a parent (or none), a position, a
velocity, a rotation and a spin in its parent, in double precision, and SHALL be part of the simulation state.
Points with their velocities and orientations SHALL convert between any two frames of a tree through their nearest
common ancestor.

#### Scenario: Across the tree
- **WHEN** a point at (1, 0, 0) in a ship frame 10 m above a planet frame (turned a quarter about +y, 1 km along +x
  in the system) is converted into the system frame
- **THEN** it is at (1000, 10, -1)

#### Scenario: Spinning frame
- **WHEN** a point at rest 10 m from the axis of a frame spinning at 1 rad/s is converted into the frame's parent
- **THEN** its velocity is 10 m/s

### Requirement: Precision far from the origin
Things in the same frame SHALL keep full precision relative to each other, however far the frame is from the root.

#### Scenario: Jitter at 100 AU
- **WHEN** a camera in a frame 100 AU from the star moves in 0.1 mm steps next to a cube in the same frame
- **THEN** the cube's position relative to the camera follows every step to better than 1 mm

### Requirement: Frame transitions
An entity's place SHALL move into another frame of the same tree while keeping its position, velocity and
orientation in the world.

#### Scenario: Entering a planet's frame
- **WHEN** a ship moving with a planet plus 7.5 km/s is moved from the system frame into the planet's frame
- **THEN** it orbits the planet at 7.5 km/s and is where it was in the system frame

### Requirement: Camera-relative drawing and scaled space
Things SHALL be drawn relative to the camera, computed in doubles. Things that end within the local or the
planetary slice's far plane SHALL be drawn in that slice where they are; farther things SHALL be drawn in the
celestial slice, moved closer and shrunk by the same factor, so their angular size is kept.

#### Scenario: A star at 1 AU
- **WHEN** a star of radius 7e8 m is 1.5e11 m from the camera
- **THEN** it is drawn in the celestial slice at the scaled distance with the same angular size

### Requirement: Scale ladder
A scene SHALL show a 1 m cube, a 144 km hull, a planet and a star in one frame tree, with the camera at each in turn.

#### Scenario: From a cube to a star
- **WHEN** the camera stands by the cube, off the hull, off the planet and off the star
- **THEN** each step matches its reference image, and the planet moves from the planetary slice into scaled space
