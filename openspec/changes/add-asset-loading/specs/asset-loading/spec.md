# Spec Delta

## Purpose

Loads textures, glTF models and sounds from the data folder (and later mods), checks them at the trust
boundary, and reloads them while the game runs during development.

## ADDED Requirements

### Requirement: Textures
Scripts SHALL load PNG and JPEG images from the data folder as textures with mipmaps, and drawing a mesh
SHALL accept a texture for its base colour. Loading the same path again SHALL return the same texture.
Images larger than 8192 pixels on a side SHALL be refused.

#### Scenario: Textured ground
- **WHEN** a script draws a plane with UVs and `texture = fk.gfx.texture("textures/test_ground.jpg")`
- **THEN** the ground shows the image, repeated as the UVs say

#### Scenario: Not an image
- **WHEN** a script loads a file that is not a PNG or JPEG image as a texture
- **THEN** a script error names the file and says it is not a PNG or JPEG image

### Requirement: glTF models
Scripts SHALL load glTF 2.0 models (`.glb`, or `.gltf` with separate or embedded buffers and images)
and draw them with their node hierarchy and PBR metallic-roughness materials: base colour, metal and
roughness, normal and emission textures and factors, including emissive strength. A model SHALL list
its clips (name and duration) and node names. Only triangle meshes are supported; other primitives
SHALL be refused with a reason.

#### Scenario: Materials showcase
- **WHEN** the materials showcase model is drawn in the lit test scene
- **THEN** each sphere shows its material: plastic, gold, painted panels with seams, brushed metal and
  a glowing core

#### Scenario: Clips are listed
- **WHEN** a script asks the Exosuit model for its clips
- **THEN** it receives idle, walk and run with their durations

#### Scenario: Broken model
- **WHEN** a model file is truncated, invalid, refers to a missing file or has indices out of range
- **THEN** loading it raises a script error that names the file and the reason

### Requirement: Skins and clips in memory
Loaded models SHALL keep their skins (joints and inverse bind matrices) and clips (translation,
rotation and scale channels with linear, step or cubic-spline keys) for the animation runtime.

#### Scenario: A skinned model
- **WHEN** a model with a two-joint skin and step, linear and cubic-spline clips is loaded
- **THEN** its skin has two joints with their inverse bind matrices and each clip keeps its keys and
  interpolation

### Requirement: Files stay inside the data folder
Paths given to the asset functions SHALL be relative paths inside the data folder without `..`, and
files referred to by a model (buffers, images) SHALL also stay inside it; data URIs are allowed.

#### Scenario: Escaping the data folder
- **WHEN** a script loads `../secret.png`, or a model refers to `../../secret.bin`
- **THEN** loading fails with a reason and no file outside the data folder is read

### Requirement: Sounds
The engine SHALL decode WAV and OGG Vorbis files to 32-bit float samples at 48 kHz, mono or stereo, up
to 60 seconds long. Longer files, other channel counts and unreadable files SHALL be refused with a reason.

#### Scenario: Resampling
- **WHEN** a 0.2 s mono WAV file at 22050 Hz is decoded
- **THEN** the result has about 9600 frames at 48 kHz

#### Scenario: Too long
- **WHEN** a 61 s OGG file is decoded as a sound
- **THEN** it is refused, before the whole file is decoded

### Requirement: Hot reload
Desktop debug builds with a window SHALL check the data folder twice a second: a changed shader SHALL
rebuild the render pipeline, a changed script SHALL restart the game from `main.lua`, and a changed
texture or model SHALL be loaded again in place. A changed file that fails to load SHALL keep the old
version and log the reason.

#### Scenario: Editing a shader
- **WHEN** a shader file is saved while the game runs from a debug build
- **THEN** the next frames use the new shader without restarting the game

#### Scenario: Fixing a script error
- **WHEN** the game shows a script error and the script is fixed and saved
- **THEN** the game starts again from `main.lua`
