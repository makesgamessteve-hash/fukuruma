# Design

## Determinism

Floats, `-ffp-contract=off` (`/fp:precise` on MSVC), only +, -, *, / and sqrt in the step. Bodies stay sorted by id
(ids are never reused; removal keeps the order), broadphase cell entries and pairs are sorted, contacts follow the
pairs, islands use union-find over that order, and the warm-start cache is sorted by (a, b, key). The C test runs a
busy scene for 10,000 steps against a recorded hash, and the physics scenario records the simulation hash after the
suit pushes a crate; both run on Linux, Windows, macOS and in the browser.

## Warm starting and stable stacks

Box contacts are keyed by their position on the reference face in 5 cm cells, not by clipping order: two equal
faces on top of each other clip to near-duplicate points whose order changes from step to step, which lost the warm
start and made stacks rock. Near-duplicates are dropped. With that, a five-box stack settles and sleeps with 10
velocity iterations.

## Saving

`world:state()` exports every field a step reads (positions, rotations, velocities, inverse masses and inertias,
sleep counters) and the warm-start cache as plain numbers: floats become doubles exactly and come back exactly.
`sim.attach` puts it into snapshots and the state hash; when nothing is attached, states hash as before.

## Characters

Collide-and-slide against everything except characters and bodies the character may push. Walkable contacts
(normal within the slope) lift it straight up, so it does not slide down slopes. A step edge (a contact between
1 cm and the step height above the foot, below 0.9 radius, with free space 5 cm into the obstacle just above the
edge) lifts the lower end until the edge lies on it: no separate step-up pass is needed, and steep slopes are not
mistaken for steps. A downward probe of the step height keeps it on the ground. Its velocity is the distance it
really moved over dt, which lets the solver push lighter bodies.
