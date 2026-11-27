# Proposal

## Why

Planet surfaces are generated from noise (plan §3.8): each planet class's terrain recipe is data in Lua that modders
can write, while the evaluation runs in tight C loops (and in jobs, for M4's meshes and M5's chunks). It must be
deterministic like all generation.

## What Changes

- `gen/noise.c`: nodes for gradient noise, fBm, ridged and billow fractals, Worley cells (distance or plate edges),
  crater fields, domain warps, combiners (add, sub, mul, min, max, blend), curves (scale, clamp, abs, terrace,
  smoothstep, power) and latitude; a checked, flat, read-only node array; integer hashing and double arithmetic only.
- `fk.noise.graph{nodes = {...}, output = ...}`: named nodes whose inputs are names, inline nodes or numbers, compiled
  with cycle detection; `graph:eval(x, y, z)`.

## Capabilities

### New Capabilities
- `noise-graphs`: recipe format, nodes, evaluation, determinism.

## Impact

`engine/src/gen/noise.{c,h}`, `engine/src/script/{lua_noise,script}.c`, `script.h`; tests `test_noise.c`,
`noise_test.lua`.
