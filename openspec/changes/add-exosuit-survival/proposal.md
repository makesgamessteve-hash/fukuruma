# Proposal

## Why

Plan M10 (hazards, survival and life), as set out in concept §5 and §5.3. The worlds should be able to kill the
Commander, and dying should mean something: Clone mode or Legacy mode, chosen for a new game. This change covers the
plan's `add-environment-model`, `add-exosuit-survival` and `add-death-modes`.

## What Changes

- **Environment model** (`environment.lua`). What a point of the world does to a body standing there:
  - its temperature, pressure and whether the air can be breathed;
  - toxins: the world's gas, toxic zones from the seed (a toxic biome) and gas pockets;
  - radiation: no air, or radiation hazards;
  - heat from vents and fire.
- **Exosuit systems** (`survival.lua`). Oxygen, filter, power and integrity, plus a radiation dose:
  - they run down outside, and inside any doll they are restored;
  - integrity is hurt by toxins once the filter is saturated, by having no power in heat or cold, by no oxygen, by
    radiation, fire, bites and falls;
  - each quarter of integrity lost is a breach, with a feedback bundle and a ship AI line;
  - the visor shows the systems and warnings.
- **Doll damage.** A sinkhole gives way under a doll or the suit standing on it; dolls keep their damage.
- **Death modes.** A game setting (the menu's "Death (new games)") chooses the mode of each new run:
  - Clone mode: the Commander wakes in the Jump Ship's clone bay; the suit is lost, with a spare in the hold it came
    from, and the dolls stay where they are;
  - Legacy mode: the run ends, and the codex of what was found (hazard kinds, worlds) is kept with `fk.storage` for the
    next Commander; F starts a new run.

## Capabilities

### New Capabilities
- `exosuit-survival`: the environment model, the suit's systems, doll damage and the death modes.

## Impact

- New: `data/scripts/{environment,survival}.lua`, `tests/lua/survival_test.lua`, and `tests/game/survival.lua`
  (slow) with its goldens.
- Changed: `main.lua`, `menu.lua`, `chain.lua` (board and teleport end a walk), `feedback.lua` and `ship_ai.lua`.
- The recorded hashes change on purpose.
