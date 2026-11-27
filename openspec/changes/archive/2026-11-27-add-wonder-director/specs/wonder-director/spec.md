## Purpose

Curates every generated system: places marvels from a moddable registry, so each system holds something remarkable,
rare marvels stay rare, and unusual signatures guide curious players.

## ADDED Requirements

### Requirement: Marvels
Marvels SHALL be a registry; each SHALL have a rarity (the share of eligible systems that get it), a prerequisite, an
effect on the system descriptor and a signature strength. There SHALL be at least ten.

#### Scenario: Rarity holds
- **WHEN** 10,000 systems are generated
- **THEN** every marvel expected at least 100 times appears in its eligible systems within 20% of its rarity

### Requirement: One marvel at least
Every system SHALL hold at least one marvel; a system that rolled none SHALL get a fallback marvel it can hold.

#### Scenario: An empty system
- **WHEN** a system with a star and no bodies is curated
- **THEN** it gets one fallback marvel

### Requirement: Unusual signatures
A system's strongest marvel signature of strength 4 or more SHALL be its unusual signature for the galaxy map, and
each system SHALL get an interest score.

#### Scenario: Signatures in the neighbourhood
- **WHEN** 10,000 systems are generated
- **THEN** more than one in ten shows an unusual signature
