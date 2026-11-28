# Replacing the art

Most of what you see is built from code and data, so better art can come in piece by piece without changing the game.

| Piece | Where it is made | How to replace it |
|---|---|---|
| Doll hulls | `data/scripts/dolls/<doll>.lua` (`hull` parts) | Edit the parts, or give the doll a glTF model and draw it in `chain.draw` (the Exosuit already uses `models/exosuit.glb`). |
| Cockpits | `dolls/cockpit.lua` from each doll's `cockpit` numbers | Change the numbers, or draw a model at the same eye point. |
| Interiors | `interior.lua` (rooms, doors, hangars) | Keep the layout (it is the walkable space) and draw kit pieces along its walls. |
| Creatures and natives | `ecology.lua`, `settlements.lua` | Skinned glTF models with a walk clip, chosen by species. The simulation only needs a position and a heading. |
| Ruins and outposts | `artifacts.lua`, `economy.lua` | Models at the same places; the pylons' glyph count is the puzzle. |
| Terrain, sky, water, clouds | the shaders in `data/shaders/` and the planet descriptors | Shader changes; the descriptors stay. |
| Sounds and music | `data/sounds`, `data/music` (`tools/audio/prompts.json`) | Change a prompt and generate it again, or put your own file at the same path. |

Rules:
- Keep the size in metres: the dolls nest by size, and the sensors resolve by size.
- Keep presentation separate. A replacement draws what the simulation says; it never moves anything itself.
- A mod can replace any of these files without touching `data/` (see `docs/MODDING.md`).
- Record where new art comes from in a `CREDITS.md` next to it. Art is CC BY 4.0 (`LICENSE-ASSETS.md`), except audio
  generated with ElevenLabs.
