# asset-layout Specification

## Purpose

Defines where the game finds its scripts, shaders and assets, so that all content lives in folders
beside the executable and can be changed or replaced without recompiling.

## Requirements

### Requirement: Data folder beside the executable
The game SHALL load all scripts, shaders and assets from a folder named `data` in the same directory
as the executable, independent of the current working directory. No file from `data` SHALL be
compiled into the executable.

#### Scenario: Started from another working directory
- **GIVEN** the executable and its `data` folder are in `/opt/fukuruma/`
- **WHEN** the game is started with `/tmp` as the working directory
- **THEN** it runs `/opt/fukuruma/data/scripts/main.lua`

#### Scenario: Changed script is used without rebuilding
- **WHEN** a file in `data/scripts/` is edited and the game is restarted
- **THEN** the game behaves according to the edited file, with the same executable

### Requirement: Missing data is reported
When `data/scripts/main.lua` cannot be found, the game SHALL exit with a non-zero exit code and log an
error that names the full path it searched. It SHALL NOT crash or show a blank window.

#### Scenario: Data folder deleted
- **WHEN** the game is started and the `data` folder beside the executable does not exist
- **THEN** it logs an error containing the searched path of `main.lua`
- **AND** it exits with a non-zero exit code

### Requirement: Web data package
The web build SHALL load the same `data` folder from a separate data file next to the WebAssembly
module, so the data can be replaced without recompiling the module.

#### Scenario: Inspecting the web build output
- **WHEN** the web build is produced
- **THEN** the output contains a data file that is separate from the `.wasm` and `.js` files
- **AND** that data file contains `data/scripts/main.lua`
