## ADDED Requirements

### Requirement: The jump drive
Star jumps SHALL start only from the Jump Ship's bridge, and only the Jump Ship SHALL go along. The other dolls SHALL
stay in their system: out of sight, reach and physics until the Jump Ship returns. In a new system, the Jump Ship's
holds SHALL deploy a new chain.

#### Scenario: Jumping away and back
- **WHEN** a jump is commanded from the Exosuit, then from the Jump Ship, and later back home
- **THEN** the first changes nothing, the second leaves the rest of the chain behind, and back home the chain is there
  again

#### Scenario: Three jumps from the bridge
- **WHEN** the Commander jumps three times from the Jump Ship's bridge
- **THEN** each arrival reaches a new system, matching the reference images
