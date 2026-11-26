# rendering Specification

## Purpose

Renders the game with modern, physically based lighting, shadows and effects at a low internal
resolution and shows it with sharp, integer-scaled pixels: the retro filter over a modern image.

## Requirements

### Requirement: Internal resolution and sharp upscale
The scene SHALL be rendered at the configured internal resolution (default 480×270) and shown at the
largest whole-number scale that fits the window, centred, with black bars and nearest-neighbour filtering.
When the window is smaller than the internal image, the image SHALL be scaled down to fit.

#### Scenario: 1080p window
- **WHEN** the window is 1920×1080 and the internal resolution is 480×270
- **THEN** every internal pixel covers exactly 4×4 window pixels and there are no bars

#### Scenario: Phone in landscape
- **WHEN** the window is 2340×1080
- **THEN** the image is shown at 4× (1920×1080), centred between two black bars

### Requirement: Physically based lighting
Scene meshes SHALL be shaded with their base colour, roughness, metalness and emission by a directional
star light, a sky/ground ambient light and up to the configured number of point lights, in high
dynamic range with automatic exposure (adapting over about a second) and a filmic tone curve.

#### Scenario: Metal and rough surfaces
- **WHEN** a smooth metal sphere and a rough plastic sphere stand in the same light
- **THEN** the metal shows a tight, bright highlight tinted by its colour and the plastic a broad, dim one

#### Scenario: Emission glows
- **WHEN** a surface has emission much brighter than its surroundings and bloom is on
- **THEN** it glows into the neighbouring pixels

### Requirement: Star shadows
The star light SHALL cast shadows from all scene meshes onto all scene meshes using 1 to 4 cascades
(0 turns shadows off), with filtered edges. Cascade placement SHALL be snapped to shadow-map texels so
that shadow edges do not shimmer while the camera moves.

#### Scenario: Shadow on the ground
- **WHEN** an object hovers above a ground plane in sunlight
- **THEN** the ground below it is darker in the object's shape

#### Scenario: Small camera movement
- **WHEN** the camera moves by less than one shadow-map texel
- **THEN** the cascade's light matrix does not change

### Requirement: Ambient occlusion
When ambient occlusion is enabled, creases and contact areas SHALL receive less ambient light.

#### Scenario: Box on the ground
- **WHEN** a box stands on the ground with ambient occlusion enabled
- **THEN** the ground right next to the box is darker than open ground farther away

### Requirement: Overlay
Scripts SHALL be able to draw unlit, vertex-coloured 2D meshes on top of the finished image, in
coordinates of the internal image, for UI and touch controls.

#### Scenario: Touch controls on top
- **WHEN** the touch controls are drawn as overlay meshes
- **THEN** they appear unlit, in their own colours, above the scene

### Requirement: Graphics configuration
Scripts SHALL be able to set the internal resolution and the quality parameters at runtime: supersampling
(1 or 2), shadow cascades (0–4) and map size (256–4096), ambient-occlusion samples (0–16), bloom,
point-light limit (0–32), HDR and dithering. Invalid values SHALL be rejected with an error naming the field.

#### Scenario: Switching resolution
- **WHEN** a script configures 640×360
- **THEN** the next frame is rendered at 640×360

#### Scenario: Invalid value
- **WHEN** a script configures 3 for supersampling
- **THEN** a script error names the field `supersample`

### Requirement: LDR fallback
When the device cannot render to floating-point targets, the pipeline SHALL switch HDR off and still
render the lit scene (tone-mapped directly, without bloom and automatic exposure).

#### Scenario: HDR switched off
- **WHEN** HDR is off
- **THEN** the scene is drawn lit, with shadows, and without bloom

### Requirement: Screenshots of the internal image
Screenshots for game tests SHALL capture the finished internal-resolution image, independent of the window size.

#### Scenario: Large window
- **WHEN** a scenario takes a screenshot in a 1280×720 window with a 480×270 internal resolution
- **THEN** the screenshot is 480×270
