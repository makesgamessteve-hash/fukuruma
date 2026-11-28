# Proposal

## Why

The plan's M6 asks for feedback that makes each doll feel its mass from inside: cabin sway and engine rumble. Until
now the seat views were rigid, and the flying dolls were silent.

## What Changes

- **Cabin sway:** the seat's view rolls into turns, with flying dolls banking harder than walking ones. It also
  pitches as the doll speeds up or brakes, eases so it lags the doll a little, and is scaled by the head-bob comfort
  setting. Stations and the Jump Ship don't sway.
- **Engine sound:** flying dolls' engines are heard from the seat, louder with speed. The new generated sound
  `engine_loop` (ElevenLabs, credited in `data/sounds/CREDITS.md`) ships only as part of the game, per the licence
  exception.
- Presentation only: nothing here changes the simulation.

## Capabilities

### Modified Capabilities
- `vehicle-controllers`: the cabin's sway and the engines' sound.

## Impact

Changed: `data/scripts/{chain,main}.lua` and `tools/audio/prompts.json`. New: `data/sounds/engine_loop.ogg`.
`tests/lua/ship_ai_test.lua` is extended. The drive, travel and Fukuruma goldens change on purpose (the sway, easing out
after a change of seat).
