## ADDED Requirements

### Requirement: A floating origin
The renderer SHALL draw positions relative to a floating origin set each frame, so that geometry far from the draw
axes' origin keeps its precision and the picture is otherwise unchanged.

#### Scenario: The Jump Ship's bridge in high orbit
- **WHEN** the Commander is on the Jump Ship's bridge 30,000 km above the range
- **THEN** the bridge is drawn whole, matching the reference image
