# Design

## Context

Models carry nodes with a rest pose, skins with inverse bind matrices, and clips with keyed channels.
Animation is presentation: it reads the simulation and frame time, and never writes simulation state.

## Decisions

### Hot loops in C, decisions in Lua
Sampling, blending and matrix building run in C over arrays of `fk_trs` (translation, rotation, scale
per node). Lua decides which clips to sample with which weights: blend trees and state machines are a
few dozen lines of Lua each, easy to extend by modders, and call C once per clip per frame.

### Sampling
Keys are found by binary search; time is clamped to the clip (looping is the caller's choice: Lua passes
`phase * duration`). Linear rotation keys use slerp (nlerp when nearly equal), cubic splines use the glTF
Hermite form and are normalised. A clip only writes the nodes it animates, so state evaluation starts
from the rest pose.

### Blending and additive layers
Blends lerp translation and scale and nlerp rotations along the shortest path. Additive layers add the
layer's difference from the rest pose (translation offset, rotation relative to the rest rotation, scale
ratio) times a weight.

### GPU skinning through a bone texture
`fk.gfx.draw(model, m, { pose })` computes node matrices, multiplies each skin joint by its inverse bind
matrix and appends the result to the frame's bone list (at most 4096 bones per frame; beyond that a
draw keeps its bind pose). The pipeline uploads the list as an RGBA32F texture (four texels per bone)
once per frame; scene-mesh shaders fetch the bones with `texelFetch` and blend four of them. A texture
avoids uniform limits on WebGL 2 and needs no per-draw uploads. Skinned draws use the draw matrix as the
skeleton's space (glTF ignores the skinned node's own transform). Unskinned draws pass bone offset -1.

### Phase-synchronised blend trees
A 1D tree blends the two entries around its parameter. All entries share one phase that advances by
`dt / mixed_duration`, so a walk and a run of different lengths keep their footfalls together. Events
belong to entries (phases such as 0.25 for the left foot) and fire from the entry with the larger weight.

### State machines
States hold a tree or a single clip. Transitions have a condition function and a fade; a one-shot clip
names the state that follows when it ends. While fading, the previous state keeps updating (trees keep
moving) and its pose is blended over the new one through a scratch pose.

### Springs
A damped harmonic spring (frequency, damping ratio) integrated with semi-implicit Euler in substeps of
1/240 s, so stiff springs stay stable at low frame rates.

## Risks / Trade-offs

- One bone texture upload per frame: about 4 KiB per Exosuit, negligible.
- Uniform scale assumed for normals in skinned meshes (as for static meshes).
