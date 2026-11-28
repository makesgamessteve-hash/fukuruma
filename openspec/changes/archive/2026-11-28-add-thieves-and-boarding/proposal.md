# Proposal

## Why

Concept §5.2: thieves who steal deployed vehicles and board your dolls. This change covers plan M11's
`add-thieves-and-boarding`; its game tests are a stolen Land Explorer tracked and recovered, and a boarding party
stopped by sealed sectors.

## What Changes

- **Raids.** Each world's thieves raid at times from its seed: the first after 4 to 10 minutes, then every 3 to 8.
- **Thefts.** A doll on the ground left unattended (nobody in it, the suit over 300 m away) is driven off to the
  hideout.
  - A stolen doll cannot be boarded.
  - Its beacon shows as a marker however far it goes.
  - Reaching it on foot and pressing F recovers it.
- **Boarding parties.**
  - When the Commander is aboard a large doll, a party of three may come in through its hangar and walk the corridor
    to the cargo deck. Every doll now has a cargo deck.
  - The seal command (L, the right stick, a touch button) shuts every door. At the shut cargo door the party waits a
    minute and then leaves.
  - If they reach the cargo deck, they loot it.
  - Boarders are drawn in the corridors.
- Feedback bundles and ship AI lines for every step.

## Capabilities

### New Capabilities
- `thieves-and-boarding`: raids, thefts, tracking and recovery, boarding parties and sealing.

## Impact

- New: `data/scripts/thieves.lua`.
- Changed: `interior.lua` (the cargo deck: layouts and interior goldens change on purpose), `chain.lua` (stolen dolls
  cannot be boarded), `main.lua`, `feedback.lua` and `ship_ai.lua`.
- Covered by `tests/lua/civilisations_test.lua` and the `civilisations` scenario.
