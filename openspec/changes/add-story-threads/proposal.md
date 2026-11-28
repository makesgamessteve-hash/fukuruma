# Proposal

## Why

Plan M13 (story threads, content and polish) asks for the mystery arc framework and its first threads, at least 40
marvels, mods with `docs/MODDING.md` and an example mod, an audio pass with ElevenLabs, and a style guide and art
replacement notes. Mod loading was planned in §3.11 but had not been built. This change covers `add-story-threads`
and the content work.

## What Changes

- **Story threads** (`story.lua`, threads in `story/*.lua`, open to mods through `story.register`). A thread is made
  of steps; each step waits for its condition, then the ship AI says its line and the step's effect runs.
- **The first thread, "The Signal".**
  - A solved ruin hums with a signal from another star within reach, chosen from the world's seed.
  - Arriving there, the signal grows stronger.
  - That star's ruin answers it, with exotic matter as the reward.
  - Finished threads go into the codex, and the codex shows the threads under way.
- **40 marvels.** 18 new ones (none a fallback, so each system's guaranteed marvel stays the same).
- **Mods.**
  - The VFS overlays `data/` with `mods/<folder>/` in load order; only plain folder names are accepted.
  - `fk.mods()` reads each `mod.lua` manifest as data, in an empty environment, and `fk.vfs_mods` sets the order.
  - `mods.lua` loads the mods first and runs their scripts once the game's modules are loaded.
  - `mods/example-mod` adds a research project and a hazard kind.
  - Every feedback bundle is now listened to, so mods can add bundles.
- **Audio pass.** 14 new ElevenLabs sounds: door, tram, flare, stun, explosion, bite, guardian, pylon, spear, alarm,
  chime, sample, collapse, breach. The new actions' and events' bundles use them, and `data/sounds/CREDITS.md` records
  them.
- **Docs.** `docs/MODDING.md`, `docs/STYLE_GUIDE.md` and `docs/ART_REPLACEMENT.md`.
- Ship AI lines wrap to the screen's width.

## Capabilities

### New Capabilities
- `story-threads`: threads of steps, "The Signal", the codex's journal.
- `mods`: the overlay, manifests, scripts and the example mod.

## Impact

- New: `data/scripts/{story,mods}.lua`, `data/scripts/story/signal.lua`, `mods/example-mod/`, the three docs,
  `tests/lua/{story,mods}_test.lua` and the sounds.
- Changed: `engine/src/assets/vfs.{c,h}`, `engine/src/script/script.c`, `CMakeLists.txt` (mods are copied beside the
  binary), `gen/wonders.lua`, `survival.lua`, `ship_ai.lua`, `feedback.lua`, `main.lua` and
  `tools/audio/prompts.json`.
- The recorded hashes change on purpose.
