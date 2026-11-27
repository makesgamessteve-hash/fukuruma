## Purpose

Gives the ground its look up close: detail, bumps, rock, snow, wetness and dust, seamless across chunks and driven by
the world's data and the weather.

## ADDED Requirements

### Requirement: Detail without seams
The terrain SHALL show fine detail and bumps up close that continue across chunk borders and fade where they would be
smaller than a pixel, without sparkling or dark pixels.

#### Scenario: A hillside
- **WHEN** the ground is seen from standing height on a terran hillside
- **THEN** it shows varied detail and bumps, matching the reference image

#### Scenario: The descent
- **WHEN** the camera descends from orbit to the ground
- **THEN** no pixel of the ground is black

### Requirement: Layers from the world
Steep ground SHALL show rock, cold ground snow, and shores wetness, following the world's data.

#### Scenario: Mountains
- **WHEN** the camera stands in high mountains
- **THEN** snow covers the level ground and rock shows through, matching the reference image

### Requirement: Layers from the weather
Rain SHALL wet the ground (darker and glossier), snowfall SHALL cover it, and dust SHALL settle on it.

#### Scenario: Rain, snowfall and dust
- **WHEN** the same hillside is drawn after rain and under snowfall, and a desert under blowing dust
- **THEN** each shows its layer, matching the reference images
