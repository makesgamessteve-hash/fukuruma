## ADDED Requirements

### Requirement: Thefts
Thieves SHALL take a doll left unattended on the ground and drive it away. While it is stolen, it SHALL NOT be
boardable, and its beacon SHALL show where it is. Reaching it on foot SHALL recover it.

#### Scenario: The Land Explorer stolen and recovered
- **WHEN** a raid comes while the Land Explorer stands alone
- **THEN** thieves drive it off, its beacon shows it, and the Commander recovers it by reaching it

### Requirement: Boarding parties
A boarding party SHALL walk from the hangar to the cargo deck and loot it, unless the sectors are sealed. If they are
sealed, it SHALL wait and then leave.

#### Scenario: Sealed sectors
- **WHEN** boarders come aboard the Jump Ship and the Commander seals the sectors
- **THEN** the boarders stop at the cargo deck's door and leave without loot
