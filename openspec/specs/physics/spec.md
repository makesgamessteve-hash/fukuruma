# physics Specification

## Purpose

Deterministic rigid-body physics and characters in C: bodies collide, rest, stack, slide and sleep, characters walk,
and every step gives the same bits on every platform.

## Requirements

### Requirement: Bodies and contacts
Scripts SHALL create physics worlds with gravity and add static, dynamic and kinematic spheres, capsules and boxes
with mass, friction, restitution and optionally their own gravity. A step SHALL move dynamic bodies under gravity
and keep bodies from passing through each other, with friction and restitution, and SHALL report new touches above
a given impulse.

#### Scenario: Stacking
- **WHEN** five 1 m boxes are stacked on the ground and the world runs for 10 s
- **THEN** each box stays within 2 cm of its place and all of them fall asleep

#### Scenario: Friction
- **WHEN** a box with friction 0.5 rests on a 15 degree slope, and another on a 40 degree slope
- **THEN** the first stays where it is and the second slides away

#### Scenario: A bounce
- **WHEN** a ball with restitution 0.8 drops 3.75 m onto the ground
- **THEN** a touch is reported and the ball comes back up more than 2 m

### Requirement: Sleeping
Groups of touching dynamic bodies that have been still for half a second SHALL fall asleep and cost nothing until a
moving body touches them or something they rest on is removed.

#### Scenario: Pulled support
- **WHEN** the lower of two stacked, sleeping boxes is removed
- **THEN** the upper one falls to the ground

### Requirement: Characters
Characters SHALL be upright capsules that move by a wanted displacement: they slide along walls, stay on slopes up
to their steepest walkable slope, climb step edges up to their step height, stay on the ground over small dips,
stop at bodies heavier than their push mass and push lighter ones.

#### Scenario: A step
- **WHEN** a character with a 0.4 m step walks into a 0.3 m step and another into a 0.7 m one
- **THEN** the first walks up onto it and the second is stopped

#### Scenario: Slopes
- **WHEN** a character with a 50 degree slope limit walks into a 25 degree ramp and into a 65 degree one
- **THEN** it walks up the first and not up the second

### Requirement: Deterministic and saveable
A world's step SHALL give the same bits on every platform. Its complete state SHALL be plain data that restores
exactly, so a restored world continues exactly as the original; a bad state SHALL be an error that leaves the world
as it was.

#### Scenario: 10,000 steps
- **WHEN** a busy scene of boxes, balls and capsules runs for 10,000 steps on Linux, Windows or macOS
- **THEN** it ends with the recorded hash

#### Scenario: Restored world
- **WHEN** a world's state is restored into another world and both run 200 more steps
- **THEN** both are in exactly the same state

### Requirement: The Exosuit in the physics world
The sandbox's Exosuit SHALL be a physics character in a world with the deck, walls along its edges, the beacon tower
and three crates it can push; new hard touches SHALL play an impact feedback bundle.

#### Scenario: Shoving a crate
- **WHEN** the Commander walks the suit into a crate for two and a half seconds
- **THEN** the crate is pushed along with an impact, the picture matches its reference image, and the state hash
  matches the recorded one on every platform

### Requirement: World gravity
A world's gravity SHALL be settable at any time (waking every body) and SHALL be part of its saved state.

#### Scenario: Another world
- **WHEN** the range jumps to a world with stronger gravity and the game is saved and loaded
- **THEN** bodies fall with the new world's gravity before and after loading
