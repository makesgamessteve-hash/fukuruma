# storage Specification

## Purpose

Keeps small text values (settings now; save games later) across restarts on every platform, isolated
from game tests.

## Requirements

### Requirement: Stored text values
Scripts SHALL be able to store and load text values by name. Names SHALL consist of lowercase letters,
digits and underscores; values SHALL be at most 64 KiB. Desktop builds SHALL keep them in the user's
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

### Requirement: Test runs are isolated
Headless, render-free, scenario and unit-test runs SHALL keep stored values in memory only, so they
neither read nor change the player's stored values or each other's.

#### Scenario: Scenario run
- **WHEN** a scenario stores settings
- **THEN** the user's application-data folder is unchanged and the next run starts without those settings
