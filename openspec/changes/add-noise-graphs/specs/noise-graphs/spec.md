## Purpose

Describes terrain recipes as graphs of noise nodes in Lua and evaluates them deterministically in C.

## ADDED Requirements

### Requirement: Noise recipes
Scripts SHALL describe a noise graph as a table of named nodes and an output. A node SHALL be an operation (gradient
noise, fBm, ridged, billow, cells, craters, warp, add, sub, mul, min, max, blend, scale, clamp, abs, terrace, smooth,
power, latitude, const) with inputs (node names, inline nodes or numbers) and parameters. Unknown nodes, missing
inputs, cycles, bad parameters and graphs of more than 256 nodes SHALL be script errors.

#### Scenario: A cycle
- **WHEN** a node takes as input a node that takes the first one as input
- **THEN** a script error says the node depends on itself

### Requirement: Deterministic evaluation
A compiled graph SHALL evaluate to the same bits at the same point on every platform, from any thread, and gradient
noise SHALL be continuous and stay within about -1..1.

#### Scenario: Recorded values
- **WHEN** a graph using every node is evaluated at 2000 recorded points on Linux, Windows or macOS
- **THEN** the values hash to the recorded one
