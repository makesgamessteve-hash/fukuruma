# Spec Delta

## MODIFIED Requirements

### Requirement: Drawing from scripts
Scripts SHALL be able to create a mesh from Lua tables of vertex positions, vertex colours (the base
colour), optional normals (computed from the triangles when absent) and triangle indices; set the camera
(view and projection matrices), the star light, the ambient light, point lights and the background
colour; and draw meshes with a model matrix and a material (roughness, metalness, emission).

#### Scenario: Spinning placeholder
- **GIVEN** `main.lua` creates a mesh from tables and draws it each frame with a growing rotation angle
- **WHEN** two frames are rendered at different times
- **THEN** the mesh appears in both frames at different rotations

#### Scenario: Normals computed
- **WHEN** a mesh is created without normals
- **THEN** each vertex gets the normalised sum of the normals of the triangles that use it

#### Scenario: Invalid material
- **WHEN** a script draws with a roughness outside 0..1
- **THEN** a script error names the field
