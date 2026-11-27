## Purpose

Fills the skies of worlds with air with lit, shadow-casting clouds, low fog and shafts of light.

## ADDED Requirements

### Requirement: Clouds
A world with clouds SHALL show a cloud layer with depth, lit by its star and drifting with the wind, seen from below,
from within and from above.

#### Scenario: Below and above
- **WHEN** the sky is seen from the ground at midday and at sunset, and the layer from above
- **THEN** the clouds show their light and shade, matching the reference images

### Requirement: Shadows, fog and shafts
Clouds SHALL shade the ground beneath them; fog SHALL lie low over the ground; light through gaps in the clouds SHALL
show as shafts in the haze.

#### Scenario: Fog and broken cloud
- **WHEN** the ground is seen through morning fog, and under broken cloud in haze
- **THEN** the fog and the light through the gaps show, matching the reference images

### Requirement: Clouds scale
The clouds' cost SHALL follow the graphics level; the lowest level SHALL have none.

#### Scenario: Off on Low
- **WHEN** clouds are off
- **THEN** the range's sky has no cloud layer
