## ADDED Requirements

### Requirement: Trams along the hangars
A doll with hangars SHALL have a tram stop at the end of its corridor and one beside each docked doll's ramp. Using a
stop SHALL ride to the next stop, wrapping round, in at most a few seconds.

#### Scenario: To the Space Station's hangar
- **WHEN** the Commander takes the tram twice from the Jump Ship's corridor
- **THEN** the Commander gets off beside the Space Station's ramp and can board it

### Requirement: Ambient drones
Drone bays and hangars SHALL have drones flying about. They SHALL be presentation only.

#### Scenario: A hangar
- **WHEN** the Commander stands in a hangar
- **THEN** drones circle in it, and the simulation state does not depend on them
