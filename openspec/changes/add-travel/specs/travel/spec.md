## Purpose

How the Commander travels along the chain: by teleport between the Jump Ship and the stations, by Drop Ship between
orbit and the ground, and by autopilot.

## ADDED Requirements

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
