# Spec Delta

## ADDED Requirements

### Requirement: Sharp temporal anti-aliasing
Temporal anti-aliasing SHALL keep the picture about as sharp as without anti-aliasing, also while the camera moves:
the history SHALL be read with a sharp (Catmull-Rom) filter and the displayed image sharpened adaptively, without the
sharpening entering the history.

#### Scenario: Walking with TAA
- **WHEN** the camera follows the walking Exosuit at the High level
- **THEN** the picture's sharpness is within 10% of the same frame without anti-aliasing
