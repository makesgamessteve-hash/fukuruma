## ADDED Requirements

### Requirement: Indoor surfaces
A draw MAY be marked `indoor`. Indoor surfaces SHALL receive no starlight. They SHALL still receive point lights,
the ambient fill and their own emission.

#### Scenario: A room inside a doll
- **WHEN** the rooms inside a doll on a sunlit planet are drawn indoor
- **THEN** no sunlight leaks onto them through gaps or shadow seams
