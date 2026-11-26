# Design

## Why not the C library

`sin` and `cos` from glibc, the Microsoft CRT, Apple's libm and Emscripten's musl usually agree, but nothing
requires them to, and one differing bit in a body's position changes the state hash and breaks replays and co-op.
fdlibm's kernels need only +, -, *, / (no fused multiply-add: `-ffp-contract=off`, `/fp:precise`), so they are
bit-identical everywhere. Reduction by pi/2 in three parts is exact for arguments up to about 1e6; mean anomalies
are wrapped into one turn before that. Recorded bit patterns in the C tests and the recorded orbit hash in the
`orbits` scenario (run on Linux, Windows, macOS and in the browser) guard it.

## Elliptic only

Bodies on rails are bound (0 <= e < 1). Hyperbolic paths (arrivals, escapes) belong to vessels under physics or a
later change, and need sinh/cosh. Newton's method starts at M (or at pi for e >= 0.8) and stops at a 1e-15 step
or after 50 iterations.

## Frames that orbit do not spin

An orbit is given in its parent's non-turning axes, so a body has two frames: the body frame (orbits, holds its
moons and ships) and a turning surface frame under it. `frames.update(t)` sets positions and velocities of
orbiting frames, and rotations and spin vectors of turning frames, from the simulation time alone.
