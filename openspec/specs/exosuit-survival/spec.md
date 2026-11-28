# exosuit-survival Specification

## Purpose

What the worlds do to the Commander: the environment model (air, temperature, toxins, radiation, fire), the Exosuit's systems and doll damage, and what happens on death (Clone mode or Legacy mode with the codex).

## Requirements

### Requirement: The environment model
The game SHALL be able to tell, for any point of a world, its temperature, pressure, breathable air, toxins,
radiation and fire. These SHALL come from the world, from its toxic zones (from its seed) and from hazards nearby.

#### Scenario: A toxic zone
- **WHEN** the suit stands inside one of the world's toxic zones
- **THEN** the environment there has toxins

### Requirement: The suit's systems
The Exosuit SHALL track oxygen, filter, power, integrity and radiation dose. Outside, they SHALL run down with the
environment. Toxins SHALL breach the suit once the filter is saturated. Inside a doll, everything SHALL be restored.

#### Scenario: Without a filter
- **WHEN** the suit stands in a toxic zone with a saturated filter
- **THEN** its integrity falls until the Commander dies

### Requirement: Death modes
Each new game SHALL be in Clone mode or Legacy mode, chosen in the settings.
- In Clone mode, a dead Commander SHALL wake in the Jump Ship's clone bay. The suit is lost, and a spare waits in its
  doll's hold.
- In Legacy mode, the run SHALL end, and the discoveries SHALL be added to a codex kept across runs.

#### Scenario: Clone mode
- **WHEN** the Commander dies in Clone mode
- **THEN** the Commander is on foot in the Jump Ship's clone bay, and the Walker holds a spare suit

#### Scenario: Legacy mode
- **WHEN** the Commander dies in Legacy mode
- **THEN** the run ends, the codex counts one more Commander and what was found, and F starts a new run

### Requirement: Doll damage
Ground that gives way SHALL damage the doll or suit standing on it.

#### Scenario: A sinkhole under the Walker
- **WHEN** the Walker stands on a sinkhole
- **THEN** the sinkhole collapses and the Walker is damaged
