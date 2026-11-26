# Spec Delta

## ADDED Requirements

### Requirement: Particle budgets
The detail levels SHALL set the most particles alive at once: Low 1000, Medium 3000, High 6000 and Ultra 12000.

#### Scenario: Low budget
- **WHEN** the level is Low and an effect emits more than 1000 particles
- **THEN** at most 1000 are alive
