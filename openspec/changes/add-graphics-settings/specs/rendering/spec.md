# Spec Delta

## MODIFIED Requirements

### Requirement: Internal resolution and sharp upscale
The scene SHALL be rendered at an internal resolution (default 480×270, or the window-shaped size when
filling the window) and shown at the largest whole-number scale that fits the window, centred, with black
bars where the shapes differ and nearest-neighbour filtering. When the window is smaller than the internal
image, the image SHALL be scaled down to fit.

#### Scenario: 1080p window
- **WHEN** the window is 1920×1080 and the internal resolution is 480×270
- **THEN** every internal pixel covers exactly 4×4 window pixels and there are no bars

#### Scenario: Phone in landscape
- **WHEN** the window is 2340×1080 and fill is off
- **THEN** the image is shown at 4× (1920×1080), centred between two black bars

## ADDED Requirements

### Requirement: Fill the window
With "fill" on (the default), the configured height SHALL be a target: the scale is the window height
divided by it, rounded down and at least 1, and the internal image is the window size divided by that
scale. When the window is smaller than the configured size, the configured size SHALL be used.

#### Scenario: Phone in landscape with fill
- **WHEN** the window is 2340×1080, the target height is 270 and fill is on
- **THEN** the internal image is 585×270, shown at 4× with no bars

#### Scenario: Small window
- **WHEN** the window is 480×270 and the configured size is 640×360 with fill on
- **THEN** the internal image is 640×360, scaled down to fit

### Requirement: Temporal anti-aliasing
When temporal anti-aliasing is on, each frame SHALL be rendered with a different sub-pixel offset and
blended with the previous result, reprojected by depth and clamped to the current frame's neighbourhood,
so edges are smooth and stable without ghosting trails behind moving objects. Reprojection that falls
outside the image SHALL use the current frame only.

#### Scenario: Still scene
- **WHEN** the camera and scene do not move for 30 frames with temporal anti-aliasing on
- **THEN** object edges show intermediate shades instead of hard stair steps

### Requirement: Palette mode
When a palette is set, the finished image SHALL use only the palette's colours (up to 64), chosen per
pixel after ordered dithering. Without a palette, colours are not restricted.

#### Scenario: Eight colours
- **WHEN** a palette of 8 colours is set
- **THEN** every pixel of the finished image (outside the overlay) is one of those 8 colours
