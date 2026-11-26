# Spec Delta

## ADDED Requirements

### Requirement: Snapshots
The simulation SHALL produce a snapshot of plain data (tick, next entity ID, living entities, components with their
iteration order, queued commands) and restore one, after which the same commands SHALL produce the same state hashes
as they did from the original state. The world seed SHALL be settable for restoring.

#### Scenario: Running on after a restore
- **WHEN** a snapshot is restored and the same five commands are applied as after taking it
- **THEN** the state hash equals the one the original run reached
