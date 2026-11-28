## ADDED Requirements

### Requirement: Species from the seed
Each world SHALL have species made from its seed by a body-plan grammar, the same every time. Its herds and packs
SHALL be sensor hazards.

#### Scenario: The same world twice
- **WHEN** a world's species are made twice
- **THEN** they are the same

### Requirement: Passive stealth
A predator SHALL notice the suit only close by while it walks, farther while it runs, and from far away after a ping.

#### Scenario: Walking past a pack
- **WHEN** the Commander walks past a predator pack 40 m away
- **THEN** none of them hunts the suit

### Requirement: Decoys and the stun
A flare SHALL draw predators within its range away while it burns. The stun SHALL stop the creatures close in front
for a while.

#### Scenario: A flare
- **WHEN** a predator hunts the suit and the Commander throws a flare
- **THEN** the predator goes for the flare and leaves the suit
