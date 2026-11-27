## MODIFIED Requirements

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
