# Design

## Context

The simulation emits events (`sim.emit`, delivered to listeners after each tick); animation emits phase
events (footsteps). Presentation must react to both without changing simulation state.

## Decisions

### Presentation listens, never writes
`feel.listen(sim, table)` registers a listener per table entry. Listeners only emit particles, start flashes,
add trauma, request rumble or play sounds. Animation events are played directly by the game's draw.

### CPU particles in a forward pass
Particles live in C (`fx/particles.c`), with their own random stream (never the simulation's), a budget set
by the detail level, and the oldest particles making room for new ones. Emitters take a cone (or a ring
across a direction), a birth sphere, speed, life, size, colour and alpha over life, gravity and drag.
The pipeline draws them after lighting (before TAA, so they are anti-aliased with the scene) into the lit
image: dust first, sorted back to front with alpha blending and lit by the ambient and star light; glowing
particles after, added. The fragment shader reads the G-buffer depth as a texture (attaching it would be a
WebGL feedback loop), discards hidden fragments and fades over 0.4 m where a particle meets a surface.
shortcut: CPU simulation and per-frame vertex upload; move to transform feedback when budgets need more than
about 10 000 particles.

### Feedback bundles in a Lua table
`feedback.lua` maps names to bundles: particles (one emitter or a list, with offsets), a light flash (a point
light fading with the square of its remaining time), trauma, hit-pause seconds, rumble and a sound name.
A strength (0..1) scales particle counts, flash and trauma. Designers and modders edit the table.

### Trauma shake
Trauma (0..1) decays by 1.2 per second. Shake is trauma squared times smooth, deterministic noise (three
sines per axis) for yaw, pitch, roll and a sideways and vertical offset, applied in camera space. Trauma
falls off linearly between 10 m and 60 m from the source and is divided by the camera doll's mass, so heavy
dolls barely feel a small step.

### Hit-pause
`feel.update(dt)` returns 0 while a hit-pause runs; the game passes that presentation time to animation and
particles. The simulation keeps its fixed ticks.

### Camera rigs
The chase rig puts six springs (eye and target positions) on a goal behind the target with a look-ahead of
velocity times seconds; the spring frequency falls with the square root of mass. Views come from a
`look_at` built from basis vectors, then the shake turns and moves them in camera space.

### Haptics
`fk.input.rumble` drives every open gamepad's low and high motors through SDL; on a phone browser, after
touch input and for strong rumbles, `navigator.vibrate`. The comfort setting can turn rumble off.

### Comfort settings
`settings/comfort.lua` stores shake and flash scales (1, 0.5, 0) and rumble with the same storage code as the
graphics settings (`settings/store.lua`). The menu gains their rows.

### Deterministic sandbox movement
The suit's tick uses only arithmetic, `sqrt`, `min` and `max` (correctly rounded everywhere), so the state hash
matches on every platform. Stick and key input become a world-space wanted velocity in presentation and
reach the simulation as `move` commands; the camera looks along +z, so the mapping needs no trigonometry.

## Risks / Trade-offs

- Particles sorted on the CPU each frame: fine for a few thousand.
- The fixed camera heading keeps controls simple; an orbiting camera comes with M6's camera work.
