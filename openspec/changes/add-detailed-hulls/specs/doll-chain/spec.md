## ADDED Requirements

### Requirement: Detailed, closed hulls
Every doll's hull SHALL be built from closed parts, with no open edges, and its joints SHALL overlap so that no gaps
show. Hulls MAY have glowing parts (windows, engines, beacons) drawn with emission. Nothing SHALL stand in front of a
doll's seat at eye height.

#### Scenario: Closed parts
- **WHEN** every part kind and every doll's hull is built
- **THEN** every edge is shared by two triangles

#### Scenario: A station in orbit
- **WHEN** the drone looks at the Space Station from 56 km away in orbit
- **THEN** the station is drawn with its rings, spokes and solar arrays, not clipped away
