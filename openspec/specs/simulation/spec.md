# simulation Specification

## Purpose

The deterministic simulation core: a fixed-rate tick, state changes through commands, events for the
presentation layer, entities with stable IDs, seeded random streams and a hash of the whole state, so
that the same history gives the same game on every platform (tests, replays, and co-op later).

## Requirements

### Requirement: Fixed tick rate
The simulation SHALL advance in ticks of exactly 1/60 s. Windowed runs SHALL run as many ticks per
frame as real time requires, at most 8 (time beyond that is dropped), and pass `draw` the fraction of
a tick that has elapsed since the last one. Headless and scenario runs SHALL run exactly one tick per frame.

#### Scenario: Slow display
- **WHEN** a windowed frame takes 1/30 s
- **THEN** two ticks run before that frame is drawn

#### Scenario: Fast display
- **WHEN** windowed frames take 1/120 s each
- **THEN** a tick runs every second frame, and the frames in between are drawn with an interpolation factor of 0.5

#### Scenario: Long stall
- **WHEN** a windowed frame takes one second
- **THEN** 8 ticks run and the rest of the time is dropped

#### Scenario: Scenario runs
- **WHEN** a scenario advances 10 frames
- **THEN** exactly 10 ticks have run

### Requirement: Commands
Game state SHALL change in response to commands: a name and arguments sent with `fk.sim.send` and
applied by the handler registered for that name. Commands sent during tick N SHALL be applied in the
order sent at the start of tick N+1, before the game's `tick`.

#### Scenario: Order and timing
- **GIVEN** handlers for "a" and "b"
- **WHEN** a script sends "b" and then "a" during a tick
- **THEN** neither handler runs during that tick, and at the start of the next tick "b" runs before "a"

#### Scenario: Unknown command
- **WHEN** a command without a handler is applied
- **THEN** a script error names the command

### Requirement: Command arguments are plain data
Command arguments SHALL be a table of finite numbers, strings, booleans and tables of those, nested
at most 8 deep. Anything else SHALL be rejected when the command is sent. The arguments SHALL be
copied when sent, so later changes by the sender do not affect the queued command.

#### Scenario: Function in the arguments
- **WHEN** a script sends a command whose arguments contain a function
- **THEN** `fk.sim.send` raises an error naming the offending field

#### Scenario: NaN in the arguments
- **WHEN** a script sends a command with a NaN or infinite number
- **THEN** `fk.sim.send` raises an error

#### Scenario: Changed after sending
- **WHEN** a script changes its argument table after sending a command
- **THEN** the handler receives the values as they were when the command was sent

### Requirement: Events
The simulation SHALL let game code emit events (a name and plain data) during a tick. After the tick,
the events SHALL be delivered in emission order to every listener registered for their name.

#### Scenario: Delivered after the tick
- **GIVEN** a listener for "footstep"
- **WHEN** the game emits "footstep" twice during a tick
- **THEN** the listener is called twice after that tick's `tick` has returned, in emission order

### Requirement: Entities
Entities SHALL be identified by integers that are never reused within a game. Components are plain
data attached to an entity by name. Iterating the entities that have a component SHALL visit them in
an order that depends only on the sequence of operations, never on memory addresses or the platform.

#### Scenario: IDs are not reused
- **WHEN** an entity is destroyed and a new one is created
- **THEN** the new ID is larger than every ID created before

#### Scenario: Destroying removes components
- **WHEN** an entity with components is destroyed
- **THEN** iterating any component no longer visits it and reading its components gives nil

### Requirement: Random streams
Random numbers for the simulation SHALL come from generators created with `fk.rng(key, ...)`, seeded by
the world seed and the given keys (strings or integers). The same seed and keys SHALL give the same
sequence on every platform. The sandbox has no global random generator.

#### Scenario: Same keys, same numbers
- **WHEN** two generators are created with the same keys in the same world
- **THEN** they produce the same sequence

#### Scenario: Recorded sequence
- **WHEN** a generator is created with world seed 1 and the key "test"
- **THEN** its first numbers equal the values recorded in the unit tests on every platform

#### Scenario: Ranges
- **WHEN** a generator is asked for integers between 1 and 6
- **THEN** every result is between 1 and 6 inclusive

### Requirement: State hash
`fk.sim.hash()` SHALL return a hash of the complete simulation state (tick number, next entity ID, every component
of every entity, and the state of attached providers such as a physics world). Identical histories SHALL give
identical hashes on every platform, independent of table iteration order and memory addresses.

#### Scenario: Same history on two platforms
- **WHEN** the simulation scenario runs on Linux, Windows, macOS and in the browser
- **THEN** each run ends with the same recorded state hash

#### Scenario: Different state
- **WHEN** one component value differs
- **THEN** the hash differs

### Requirement: Snapshots
The simulation SHALL produce a snapshot of plain data (tick, next entity ID, living entities, components with their
iteration order, queued commands, and the states of attached providers) and restore one, after which the same
commands SHALL produce the same state hashes as they did from the original state. The world seed SHALL be settable
for restoring.

#### Scenario: Running on after a restore
- **WHEN** a snapshot is restored and the same five commands are applied as after taking it
- **THEN** the state hash equals the one the original run reached

#### Scenario: Attached physics
- **WHEN** the sandbox is saved, a crate is moved, and the save is loaded
- **THEN** the crate is back exactly where it was
