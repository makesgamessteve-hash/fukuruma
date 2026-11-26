# Spec Delta

## MODIFIED Requirements

### Requirement: Script modules
Scripts SHALL be able to load other scripts with `require("a.b")`, which loads `data/scripts/a/b.lua`
through the engine's data folder lookup. `require("game")` SHALL return the table returned by
`data/scripts/main.lua`.

#### Scenario: Requiring a module
- **GIVEN** a file `data/scripts/dolls/walker.lua` that returns a table
- **WHEN** a script calls `require("dolls.walker")`
- **THEN** it receives that table

#### Scenario: The game table
- **WHEN** a scenario calls `require("game")` and replaces its `draw` function
- **THEN** the following frames are drawn by the new function
