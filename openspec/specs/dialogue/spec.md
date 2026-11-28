# dialogue Specification

## Purpose

Talking to natives and the game's menus: trees of nodes and options written in Lua, with effects on reputation and the world.

## Requirements

### Requirement: Talking to natives
The Commander SHALL be able to talk to a native within reach. The talk SHALL start at a node chosen by the faction's
attitude. Options SHALL be offered only when the attitude allows them, and they MAY change the reputation or reveal
places.

#### Scenario: Asking about the ruins
- **WHEN** the Commander asks a friendly native about the old ruins
- **THEN** the ruin becomes a sensor contact, shown however far away it is
