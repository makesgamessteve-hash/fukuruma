## ADDED Requirements

### Requirement: Story threads
The game SHALL run story threads made of steps. Each step SHALL wait for its condition, then speak its line and
apply its effect. Finished threads SHALL go into the codex.

#### Scenario: The Signal
- **WHEN** the Commander solves a ruin, jumps to the star the signal points at, and solves that star's ruin
- **THEN** the thread moves through its three steps, rewards exotic matter and is marked answered
