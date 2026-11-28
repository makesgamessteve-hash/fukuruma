# artifact-sites Specification

## Purpose

The ruins of dead civilisations: their pylon puzzle, their guardian and their artifact.

## Requirements

### Requirement: The ruin's puzzle
Each world SHALL have a ruin whose pylons must be woken in the order their glyphs give. A wrong pylon SHALL reset the
puzzle and wake a guardian that hurts the suit nearby for a while. The right order SHALL yield the artifact, which
goes into the codex.

#### Scenario: Wrong, then right
- **WHEN** the Commander touches a wrong pylon, then all three in the right order
- **THEN** the guardian wakes first, and then the artifact is found
