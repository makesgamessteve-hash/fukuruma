# Spec Delta

## ADDED Requirements

### Requirement: Skinned meshes
The G-buffer and shadow passes SHALL transform skinned vertices by up to four bone matrices weighted per
vertex; unskinned meshes SHALL be unaffected.

#### Scenario: Shadow of a pose
- **WHEN** a walking Exosuit stands in the star light
- **THEN** its shadow shows the walking pose, not the bind pose
