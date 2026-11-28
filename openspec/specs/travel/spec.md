# travel Specification

## Purpose

Getting between the dolls over large distances: the teleport network between the Jump Ship and the stations, and the Drop Ship's autopilot between orbit and the ground.

## Requirements

### Requirement: The jump drive
Star jumps SHALL start only from the Jump Ship's bridge, and only the Jump Ship SHALL go along. The other dolls SHALL
stay in their system: out of sight, reach and physics until the Jump Ship returns. In a new system, the Jump Ship's
holds SHALL deploy a new chain.

#### Scenario: Jumping away and back
- **WHEN** a jump is commanded from the Exosuit, then from the Jump Ship, and later back home
- **THEN** the first changes nothing, the second leaves the rest of the chain behind, and back home the chain is there
  again

#### Scenario: Three jumps from the bridge
- **WHEN** the Commander jumps three times from the Jump Ship's bridge
- **THEN** each arrival reaches a new system, matching the reference images

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

### Requirement: Between orbit and the ground
Between a doll in orbit and a doll on or over the ground, the Commander SHALL go only by Drop Ship. A Drop Ship SHALL
dock with any doll near it.

#### Scenario: No climbing into orbit
- **WHEN** the Commander tries to board the station from the Continental Explorer
- **THEN** nothing happens, until a Drop Ship has flown there

### Requirement: Teleport network
The Commander SHALL teleport between the Jump Ship and any station, however far apart, and only between them.

#### Scenario: To the Jump Ship
- **WHEN** the Commander teleports from the station
- **THEN** the view is from the Jump Ship's bridge, matching the reference image

### Requirement: Autopilot
A doll SHALL travel to another doll by itself on autopilot, arrive near it, and keep going after the Commander has
left. Steering by hand SHALL cancel it. Flying dolls SHALL go faster the higher they are.

#### Scenario: Up to orbit and back down
- **WHEN** a Drop Ship from the Continental Explorer flies on autopilot to the station, and later back down
- **THEN** it arrives at each, and the views match the reference images
