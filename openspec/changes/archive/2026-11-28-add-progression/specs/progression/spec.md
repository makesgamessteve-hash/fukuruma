## ADDED Requirements

### Requirement: Samples and research
The Commander SHALL be able to take samples on foot and put them into research projects. Done projects SHALL upgrade
the dolls, including their sensor suites.

#### Scenario: Bio-sensors
- **WHEN** a grazer's sample is researched into bio-sensors
- **THEN** the Exosuit sees a predator 160 m away that it could not see before

### Requirement: Markets
Each friendly settlement SHALL be a market whose prices come from the seed, rise as it is bought from, fall as it is
sold to, and fall with good reputation.

#### Scenario: Buy low, sell high
- **WHEN** the Commander buys a good where it is cheap and sells it where it is dear
- **THEN** the credits grow by the difference

### Requirement: Crafting and outposts
The workshop SHALL craft items from recipes. An outpost kit SHALL build an outpost that takes modules and stays as
built on its world.

#### Scenario: Leaving and coming back
- **WHEN** the Commander builds an outpost with a power module, jumps to another system and back
- **THEN** the outpost is where it was, with its module

### Requirement: The codex
The codex SHALL list what is known, and the Commander SHALL be able to name the species found. Names SHALL be kept
for every Commander after.

#### Scenario: Naming a species
- **WHEN** the Commander names a species found
- **THEN** the codex keeps its name
