# Proposal

## Why

M2's last part (plan §3.6): deterministic physics in C, so the Exosuit stops at walls, climbs low steps and moves
the things it walks into, and so later vehicles, debris and cargo have a body to stand on. It runs inside the
simulation, so it must give the same bits on every platform and belong to saves and the state hash.

## What Changes

- **Physics module** (`engine/src/physics/`): spheres, capsules and boxes; a broadphase grid (bodies wider than
  64 cells are tested against all); narrowphase for every pair (box against box by separating axes with face
  clipping and edge contacts); a sequential-impulse solver with friction, restitution, Baumgarte correction and
  warm starting (contacts keyed by where they are on the reference face); islands that fall asleep; static,
  dynamic and kinematic bodies; gravity per world and per body. Floats with only arithmetic and sqrt, every loop
  in creation or sorted order.
- **Characters:** kinematic capsules that walk with collide-and-slide, stay on walkable slopes, ride up step edges
  no higher than their step height (when there is room above the edge), stick to the ground over dips, stop at
  bodies heavier than their push mass and push lighter ones (the solver moves them).
- **Scripts:** `fk.physics.world{gravity}` with `add`, `character`, `remove`, `get`, `set`, `move`, `step` (new
  touches above an impulse), `count`, `state` and `restore` (exact; a bad state leaves the world as it was).
- **Simulation:** `sim.attach(name, provider)` puts state kept outside the components (the physics world) into
  snapshots and the state hash.
- **Sandbox:** a physics world with the deck, walls along its edges, the beacon tower and three 400 kg crates; the
  Exosuit is a character (radius 0.8 m, step 0.5 m, pushes up to 800 kg); new touches play an `impact` feedback
  bundle (grit, a boom generated with ElevenLabs, a jolt, rumble).

## Capabilities

### New Capabilities
- `physics`: bodies, contacts, sleeping, characters, determinism, saving.

### Modified Capabilities
- `simulation`: attached state in snapshots and the state hash.

## Impact

`engine/src/physics/{physics.h,vec.h,collide.c,world.c}`, `engine/src/script/lua_physics.c`, `script.c/h`;
`data/scripts/fk/sim.lua`, `main.lua`, `feedback.lua`; `data/sounds/impact.ogg` (credited); tests `test_physics.c`,
`physics_test.lua`, `main_test.lua`, `tests/game/physics.lua` with a golden; the simulation scenario's hash.
Later: convex hulls, triangle meshes, heightfield and voxel chunks (with terrain in M5), vehicles (M6), jump jets and
climbing.
