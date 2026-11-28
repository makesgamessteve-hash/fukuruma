# Proposal

## Why

Plan M12 (progression and economy), from concept §3: samples, research and upgrades, markets with reputation pricing,
crafting, outposts, and the codex with naming. It covers the plan's `add-research`, `add-trading`, `add-crafting`,
`add-outposts` and `add-codex`. Its game tests are:
- the sample → research → sensor upgrade loop;
- buying low and selling high between two markets;
- an outpost that is unchanged after leaving and coming back.

## What Changes

- **Samples** (F on foot): grazers, vents, gas pockets, radiation, and stunned predators, each once. A solved ruin
  gives exotic matter.
- **Research** (`research.lua`, tree in `research/tree.lua`, open to mods).
  - Projects cost samples, have prerequisites and run one at a time over their time.
  - Done projects upgrade the sensor suites (Exosuit bio-sensors, the Walker's chemical mapping), the filter's life,
    the armour and the jump range (`universe.reach`).
- **Trading** (`economy.lua`). Settlements whose natives are curious or friendlier are markets ("Trade." in a talk).
  - Prices come from the seed per market and good, move with each purchase and sale, and get a reputation discount.
    A market pays 85% of its price.
  - Credits and goods (ore, spice, crystal, tools) are carried.
- **Crafting** (the workshop, K, in a doll or at an outpost). Recipes:
  - filter cartridges, swapped in when the filter is saturated;
  - repair kits, used at once below 30% integrity;
  - outpost kits.
- **Outposts.** H unpacks a kit where the suit stands, one per world. Modules from the workshop:
  - power, which restores the suit nearby;
  - storage;
  - a landing pad;
  - a scanner, which scans like a Walker.
  Outposts are simulation state, so they are there after a jump away and back.
- **Codex** (X). Entries known and found this run, and a name for each species found, chosen from three made from
  its name. Names are kept in `fk.storage` across runs.
- **Menus.** The dialogue UI becomes the game's menu: options and text made from state, actions, a fourth option, and
  a dark panel. Cockpit screens hide behind it.
- Feedback bundles and ship AI lines for each new action.

## Capabilities

### New Capabilities
- `progression`: samples, research and upgrades, markets, crafting, outposts and the codex.

## Impact

- New: `data/scripts/{economy,research}.lua`, `data/scripts/research/tree.lua`, `tests/lua/progression_test.lua`, and
  `tests/game/progression.lua` (slow) with its goldens.
- Changed: `dialogue.lua` and `dialogue/natives.lua`, `sensors.lua`, `survival.lua`, `universe.lua`, `navmap.lua`,
  `main.lua`, `feedback.lua` and `ship_ai.lua`.
- The recorded hashes change on purpose.
