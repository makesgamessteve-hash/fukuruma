## MODIFIED Requirements

### Requirement: Poses and clips
Scripts SHALL create poses of a model, sample its clips into them at a time (clamped to the clip) with a
weight, blend and copy poses, add clips as additive layers, turn and scale single nodes, and read the model-space
matrix of a node. Clip keys SHALL be interpolated as the file says: linear (rotations along the shortest
arc), step or cubic spline.

#### Scenario: Walking stride
- **WHEN** the Exosuit's walk clip is sampled a quarter of the way through its cycle
- **THEN** the left foot is in front of the body and the right foot behind it

#### Scenario: Half weight
- **WHEN** a clip is sampled with weight 0.5 over the rest pose
- **THEN** every animated node lies between its rest pose and the clip's pose

#### Scenario: Unknown clip
- **WHEN** a script samples a clip the model does not have
- **THEN** a script error names the clip

#### Scenario: Hidden head
- **WHEN** the Exosuit's head node is scaled to 0
- **THEN** the antenna on the head has a zero matrix too
