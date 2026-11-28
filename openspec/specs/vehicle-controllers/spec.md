# vehicle-controllers Specification

## Purpose

How each doll moves when steered from its seat: legged, flight, orbit and fixed controllers driven by throttle, turn and lift.

## Requirements

### Requirement: Feeling the doll's mass
At a doll's controls, the view SHALL roll into the doll's turns and pitch as it speeds up or brakes, scaled by the
head-bob comfort setting. A flying doll's engines SHALL be heard, louder with its speed.

#### Scenario: A banking turn
- **WHEN** the Commander flies the Continental Explorer in a climbing turn
- **THEN** the bridge's view banks into the turn, matching the reference image, and the engines are heard

### Requirement: Steering from the seat
The doll the Commander sits in SHALL follow the drive command: throttle, turn and lift, each clamped to -1..1. A doll
the Commander leaves SHALL stop. The Exosuit SHALL keep walking with the move command.

#### Scenario: Leaving the controls
- **WHEN** the Commander walks the Walker and then boards another doll
- **THEN** the Walker comes to a stop

### Requirement: Legged dolls
Legged dolls SHALL walk on the ground at their own speed and rate of turn. Each stride SHALL shake the ground with a
feedback bundle scaled by the doll's size, and the seat SHALL bob with the stride.

#### Scenario: The Walker walks
- **WHEN** the Commander drives the Walker forward for ten seconds
- **THEN** it has moved forward on the ground with a stomp at every stride, and its cab looks out where it walked,
  matching the reference image

### Requirement: Flying dolls
Flying dolls SHALL fly, climb and turn, and stay at least their floor height above the ground. Fixed dolls SHALL hold
their place.

#### Scenario: The Continental Explorer climbs
- **WHEN** the Commander flies the Continental Explorer forward, climbing and turning
- **THEN** it rises and turns, never drops below its floor, and its bridge's view matches the reference image
