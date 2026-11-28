# Proposal

## Why

Plan M10 asks for fire that spreads through dry vegetation, smoke, explosions and toxic gas as visible hazards. This
change covers the plan's `add-fire-and-destruction`.

## What Changes

- **Fire on a grid of 8 m cells.** A flare or an explosion lights a cell. Every half second each burning cell may
  light its neighbours, more likely the drier the world's vegetation; there is none without air, or where it is too
  cold or too hot. The draws are deterministic, a named stream per world, tick and cell. A cell burns for 12 seconds
  and then is ash.
- **Explosions.** A gas pocket in a burning cell explodes: it is gone, the suit nearby is hurt and creatures nearby
  are knocked down.
- **Damage.** Standing in fire burns the suit, through the environment model.
- **Presentation.** Flames, smoke and flickering light over the nearest burning cells; explosion and flare feedback
  bundles.

## Capabilities

### New Capabilities
- `fire`: spreading fire, ash and explosions.

## Impact

New: `data/scripts/fire.lua`. Changed: `main.lua` and `feedback.lua`. Covered by `tests/lua/survival_test.lua`.
