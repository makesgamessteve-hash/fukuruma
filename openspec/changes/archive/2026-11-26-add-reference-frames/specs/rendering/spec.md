## ADDED Requirements

### Requirement: Depth slices
Draws SHALL go into one of four depth slices: near (cockpits, hands), local (the default, with the camera's
projection), planetary and celestial, each with its own near and far planes that scripts can set. A nearer slice
SHALL always be in front of a farther one, and lighting, ambient occlusion, temporal anti-aliasing and particles
SHALL use each pixel's own slice. It SHALL work on WebGL 2.

#### Scenario: A cube in front of a hull
- **WHEN** a 1 m cube in the local slice is drawn 3 m from the camera in front of a 144 km hull in the planetary slice
- **THEN** the cube is in front of the hull and both are lit

#### Scenario: Unchanged scenes
- **WHEN** a scene draws only into the local slice
- **THEN** it looks as it did before depth slices
