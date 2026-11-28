# Style guide

How Fukuruma looks, sounds and speaks, so that new content fits what is there.

## Look

- **Modern light, retro resolution.** PBR materials, shadows, ambient occlusion, bloom and volumetrics, all rendered at
  a low internal resolution (the "Classic" 480×270 by default). Only the resolution is retro; the light is not.
- **Hard-surface dolls.** Hulls are built from boxes and greebles (`dolls/hull.lua`) in two or three colours per doll:
  a hull colour, a dark trim and glass. Metalness and roughness come from the doll's definition.
- **Living things are soft and simple.** Creatures and natives are a few boxes in earthy colours, with procedural
  legs. Predators have red eyes.
- **Light tells you what matters.** Room lights are white-blue, fires and flares orange-red, scan markers cyan,
  danger red, the story's moments violet.
- **Visor and screens.**
  - Text is the 8-pixel font, centred where it belongs: markers where things are, the ship AI at the bottom, menus on
    a dark panel.
  - Cyan is information, amber is what you can do, red is a warning, grey is old data.

## Sound

- Generated with ElevenLabs (`tools/audio/prompts.json`): short, close and physical for actions, and wide, calm loops
  for ambience. Each sound's prompt is kept with it, so it can be generated again.
- Every player action has a sound in its feedback bundle (`feedback.lua`), together with rumble, camera shake and,
  where it fits, light and particles.

## Voice

- **The ship AI** speaks in short capitals: what happened, then what to do. For example: "INTRUDER ALERT: BOARDERS
  IN THE JUMP SHIP. SEAL THE SECTORS (L)."
- **Natives** speak in quotes, plainly, without modern words: "'The takers live far from here.'"
- **Names** of species, factions and people are made from syllables by seeded streams. Players can rename species
  in the codex.
- All of the ship AI's lines are in `data/scripts/strings/en.lua`; new lines go there too.

## Accessibility

- Every action can be rebound in the settings (keys). Touch and gamepad have their own layouts.
- Everything the ship AI says is on screen; there is no spoken line without text.
- Camera shake, light flashes, rumble, head bob, field of view and the turning vignette can be turned down. The
  colour vision setting corrects for protanopia, deuteranopia and tritanopia.
