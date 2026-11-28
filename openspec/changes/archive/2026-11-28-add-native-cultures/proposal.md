# Proposal

## Why

Plan M11 (civilisations and villains), from concept §5.2: natives with attitudes and their own peoples, and
spacefaring civilisations. This change covers the plan's `add-factions`, `add-native-settlements` and
`add-dialogue`.

## What Changes

- **Factions** (`factions.lua`). Each world has its natives and its thieves, and each system its spacefarers. Each
  faction has a name and a base attitude from the seed. Reputation (-100..100) moves the attitude one step per 25
  points, from hostile through territorial, fearful and curious to trading.
- **Settlements** (`settlements.lua`). Worlds with air and a liveable climate (150–420 K) get two settlements from the
  seed: a ring of huts and towers in their own colours around a fire, built from hull parts.
  - Six natives each walk between the buildings and stop to look at a suit nearby.
  - Natives are sensor signatures.
  - Hostile natives throw spears at a suit that comes close.
- **Dialogue** (`dialogue.lua`, trees in `dialogue/*.lua`, open to mods through `dialogue.register`).
  - F near a native starts a talk at the node for the faction's attitude. Keys 1 to 3, the gamepad's A, X and Y, or
    touch buttons choose.
  - Options can need a better attitude, change the reputation (respect, a gift, an insult) or reveal things: the
    ruin's place and the thieves' hideout become sensor contacts that show however far away they are.
  - The open talk is simulation state, so it is saved. The suit holds still during it.
- `chain.hands`: other modules can offer what F does on foot (talk, touch a pylon, recover a doll).
- `game.init` stops the old ambient loops, so a new run (Legacy mode) does not pile up sounds.

## Capabilities

### New Capabilities
- `factions`: factions from the seed, reputation and attitudes.
- `native-settlements`: settlements, natives and their reactions.
- `dialogue`: dialogue trees, talks and their effects.

## Impact

- New: `data/scripts/{factions,settlements,dialogue}.lua`, `data/scripts/dialogue/natives.lua`, and
  `tests/lua/civilisations_test.lua` with the factions, settlements and dialogue parts of the `civilisations`
  scenario.
- Changed: `chain.lua`, `sensors.lua` (a list of world hooks), `main.lua`, `feedback.lua` and `ship_ai.lua`.
- The recorded hashes change on purpose.
