# Spec Delta

## ADDED Requirements

### Requirement: Material textures
A material's base colour, roughness, metalness and emission SHALL be its factors times its textures
(base colour and emission in sRGB; roughness in green and metalness in blue, as in glTF), and a normal
map SHALL perturb the surface normal by the material's normal scale.

#### Scenario: Normal map
- **WHEN** a smooth sphere has a normal map of recessed panel seams
- **THEN** the seams catch the light as grooves although the geometry is smooth

#### Scenario: Untextured meshes
- **WHEN** a mesh is drawn without textures
- **THEN** it looks as before: its vertex colour and the draw's factors
