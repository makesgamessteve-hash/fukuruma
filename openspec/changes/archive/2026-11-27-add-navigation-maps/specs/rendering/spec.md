## ADDED Requirements

### Requirement: Star map sky
The renderer SHALL show a cube map where nothing is drawn, scaled by a strength and turned by a rotation, and scripts
SHALL bake the night sky seen from any point of the galaxy into one in the background: the stars within a radius at
their apparent brightness and colour, over the galactic band.

#### Scenario: The sky from home
- **WHEN** the sky from the home star is baked and shown at night
- **THEN** stars of different colours and the galactic band are visible
