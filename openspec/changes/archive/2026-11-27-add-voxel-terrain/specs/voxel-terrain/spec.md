## Purpose

Lets the suit dig pits and tunnels into the world's ground that bodies and the suit can enter, and that last through a
save and load.

## ADDED Requirements

### Requirement: Digging
The suit SHALL dig a hole into the ground in front of it on command: from the surface a pit, from inside a hole a
tunnel forward and down with room for the suit; not into the deck.

#### Scenario: A tunnel
- **WHEN** the suit digs a pit and then digs on from inside it, walking into each new hole
- **THEN** it stands more than 4 m below the surface with ground over its head, matching the reference images

### Requirement: The ground has holes
Bodies and the suit SHALL fall into dug holes and walk through them; ground SHALL remain where it was not dug.

#### Scenario: A ball and a pit
- **WHEN** a ball is dropped over a pit
- **THEN** it comes to rest on the pit's floor

### Requirement: Digs last
Digs SHALL be part of the saved game; a loaded game SHALL have the same holes and continue exactly.

#### Scenario: Save, load, walk through
- **WHEN** the game is saved after digging, then loaded
- **THEN** the tunnel is there and the suit walks down it again
