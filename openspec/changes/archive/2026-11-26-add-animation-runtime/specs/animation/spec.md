# Spec Delta

## Purpose

Plays and blends the clips of glTF models, skins them on the GPU, and gives scripts blend trees, state
machines and springs. Animation is presentation and never changes the simulation.

## ADDED Requirements

### Requirement: Poses and clips
Scripts SHALL create poses of a model, sample its clips into them at a time (clamped to the clip) with a
weight, blend and copy poses, add clips as additive layers, turn single nodes, and read the model-space
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

### Requirement: Skinned drawing
Drawing a model with a pose SHALL move its skinned meshes with their joints on the GPU, in the G-buffer
and in the shadow passes, for any number of skinned draws up to 4096 bones per frame; draws beyond that
SHALL keep their bind pose.

#### Scenario: Skinning showcase
- **WHEN** the Exosuit is drawn idling, walking and running at fixed clip times
- **THEN** the image matches the reference, with shadows that follow the poses

### Requirement: Blend trees
A 1D blend tree SHALL blend the two clips around a parameter value, keep all its clips at one shared phase
so cycles of different lengths stay in step, and report events placed at phases of the dominant clip.

#### Scenario: Footsteps
- **WHEN** the tree plays the walk for one second at walking speed
- **THEN** it reports one left and one right footstep, and none while standing

### Requirement: State machines
A state machine SHALL switch between blend trees and clips by conditions or by request, crossfade over
the given time, and return from a one-shot clip to the named state when the clip ends.

#### Scenario: One-shot clip
- **WHEN** a condition starts a one-shot clip with a 0.2 s fade
- **THEN** the pose blends from the old state to the clip over 0.2 s, and the machine returns to the
  named state when the clip ends

### Requirement: Springs
Scripts SHALL have damped springs with a frequency and a damping ratio that follow a target and can be
kicked, stable for long frames.

#### Scenario: No overshoot
- **WHEN** a spring with damping 1 follows a step of 1 for one second at 2 Hz
- **THEN** it ends within 0.001 of the target without overshooting
