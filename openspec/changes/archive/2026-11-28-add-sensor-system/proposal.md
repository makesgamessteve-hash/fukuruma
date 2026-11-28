# Proposal

## Why

Plan M9 (sensors and scanning) builds on concept §5.1, the sensor pyramid. Every danger has a signature, and every doll
sees only what its sensors resolve. What kills you is smaller than your vehicle's resolution, so you watch the
Exosuit's visor. What kills your vehicle is at least its size, so you scan ahead from the doll above. This change
covers the plan's `add-sensor-system`, `add-scan-overlays` and `add-exosuit-hud`.

## What Changes

- **Signatures.** Each hazard has a kind (thermal, bio, EM, seismic, chemical, exotic), a size and a stealth. The
  hazard registry (`sensors.HAZARDS`, open to mods) holds sinkholes, gas pockets, radiation, predators (hostile, they
  roam) and hot vents. Each world gets 40 hazards from its seed (a named stream), within 4 km of the range's origin.
- **Sensor suites.** Every doll definition gets `sensors = {range, resolution, kinds}`, following the concept's table.
- **Passive and active scans.**
  - Passive scans run every half second for the doll the Commander is in and for any doll on autopilot. Stealth
    shortens their range.
  - The scan command (E) is now an active ping, from the Exosuit or from any doll's seat. It reaches twice as far,
    resolves half as small and ignores stealth. Every hostile within its reach hears it and becomes alerted, roaming
    faster, with a feedback bundle and a ship AI warning.
- **Ageing data.** Contacts keep where and when each hazard was last seen. Roaming hazards move on, and after 60
  seconds a contact is shown as stale, with its age.
- **Overlays and HUD.**
  - Contacts are drawn where they are, as augmented reality on the visor and through the cockpit windows.
  - The visor lists the nearest three.
  - Each cockpit gets a sensor screen showing the contacts and how many are old.
- **Hazard stops.** A doll on autopilot stops when a known contact is in its way: ahead, within its stopping distance,
  across its path, and at least a tenth of its size. It hands control back with a bundle and a ship AI line.

## Capabilities

### New Capabilities
- `sensor-system`: signatures, suites, scans, contacts, overlays and hazard stops.

## Impact

- New: `data/scripts/sensors.lua`, `tests/lua/sensors_test.lua`, and `tests/game/sensors.lua` (slow) with its goldens.
- Changed: the doll definitions, `chain.lua` (the hazard stop and the sensor screen), `main.lua`, `feedback.lua` and
  `ship_ai.lua`.
- The recorded hashes change on purpose: the hazards are simulation state.
