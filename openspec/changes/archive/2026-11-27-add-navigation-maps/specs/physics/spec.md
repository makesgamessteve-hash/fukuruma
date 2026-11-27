## ADDED Requirements

### Requirement: World gravity
A world's gravity SHALL be settable at any time (waking every body) and SHALL be part of its saved state.

#### Scenario: Another world
- **WHEN** the range jumps to a world with stronger gravity and the game is saved and loaded
- **THEN** bodies fall with the new world's gravity before and after loading
