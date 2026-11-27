## MODIFIED Requirements

### Requirement: Digging
The suit SHALL dig a hole into the ground in front of it on command. From the surface it SHALL dig a pit. From inside
a hole it SHALL dig a tunnel forward and down with room for the suit, for as many digs as it keeps digging. It SHALL
NOT dig into the deck.

#### Scenario: A tunnel
- **WHEN** the suit digs a pit and then digs on from inside it, walking into each new hole
- **THEN** it stands more than 4 m below the surface with ground over its head, matching the reference images

#### Scenario: Overlapping digs
- **WHEN** the distance to the solid is measured midway between two overlapping digs deep under the ground
- **THEN** it is the distance to the crease where their walls meet, not less

## ADDED Requirements

### Requirement: Light underground
Below the ground, the sky's ambient light SHALL fade with the eye's depth, and a helmet lamp SHALL light the dug walls.

#### Scenario: Looking back up a tunnel
- **WHEN** the suit stands deep in a tunnel and looks back towards its opening
- **THEN** the walls are lit warmly by the lamp and the opening is bright, matching the reference image
