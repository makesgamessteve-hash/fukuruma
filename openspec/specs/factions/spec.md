# factions Specification

## Purpose

Who lives in the galaxy besides the Commander: natives, thieves and spacefarers made from the seed, the reputation the Commander earns with each, and the attitude it gives them.

## Requirements

### Requirement: Factions and reputation
Each world SHALL have natives and thieves, and each system spacefarers, made from the seed. What the Commander does
SHALL change the reputation with them, and the reputation SHALL shift each faction's attitude, from hostile to
trading.

#### Scenario: A faction turns
- **WHEN** the reputation with a faction falls to its lowest
- **THEN** the faction is hostile, whatever its base attitude was
