# Spec Delta

## MODIFIED Requirements

### Requirement: Stored text values
Scripts SHALL be able to store and load text values by name. Names SHALL consist of lowercase letters,
digits and underscores; values SHALL be at most 4 MiB. Desktop builds SHALL keep them in the user's
application-data folder and web builds in the browser's IndexedDB, so they survive restarts and reloads.

#### Scenario: Round trip
- **WHEN** a script stores "level=ultra" as "graphics" and later loads "graphics"
- **THEN** it receives "level=ultra"

#### Scenario: Missing value
- **WHEN** a script loads a name that was never stored
- **THEN** it receives nil

#### Scenario: Invalid name
- **WHEN** a script stores a value as "../evil"
- **THEN** a script error names the problem and nothing is written

#### Scenario: Too large
- **WHEN** a script stores more than 4 MiB under one name
- **THEN** a script error says so and nothing is written
