## ADDED Requirements

### Requirement: Mods
Folders under `mods/` with a `mod.lua` manifest SHALL overlay the game's files in load order. Their scripts SHALL
register content through the game's registries. Manifests SHALL be read as data. Folder names other than plain
words SHALL be ignored.

#### Scenario: The example mod
- **WHEN** the game starts with `mods/example-mod` beside it
- **THEN** its research project and hazard kind are registered, and its scripts resolve through the overlay
