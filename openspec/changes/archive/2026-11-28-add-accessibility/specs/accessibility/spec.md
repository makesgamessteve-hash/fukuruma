## ADDED Requirements

### Requirement: Key bindings
Each main action SHALL be rebindable from the settings menu, and the bindings SHALL be saved.

#### Scenario: Rebinding use
- **WHEN** the player chooses the use row and presses J
- **THEN** use is on J now and after a restart, and Escape instead keeps the old key

### Requirement: Colour vision
The player SHALL be able to choose a colour vision correction for protanopia, deuteranopia or tritanopia.

#### Scenario: Protanopia
- **WHEN** the player chooses protanopia
- **THEN** the final image goes through its correction matrix

### Requirement: String tables
The ship AI's lines SHALL come from string tables by key, falling back to English.

#### Scenario: A missing language
- **WHEN** the language has no table
- **THEN** the English line is shown
