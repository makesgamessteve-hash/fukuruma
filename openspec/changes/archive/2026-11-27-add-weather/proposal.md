# Proposal

## Why

Worlds with air should have weather you can stand in: rain and thunderstorms on worlds with seas, snow on cold worlds,
sandstorms on dry ones (CONCEPT §4.5; plan M5: "weather: rain, snow, sandstorms, lightning, wet and snowy ground").

## What Changes

- `weather.lua`: the weather comes in spells of eight minutes. A hash of the world and the spell's number picks its kind
  from the kinds the world can have, and each spell rises and falls again. The same world at the same time always has
  the same weather. Presentation only: the simulation never reads it.
- A spell shows as falling rain, snow or sand around the eye, extra cloud cover and fog. The ground's wet, snow and dust
  layers follow it. Each kind has a looping sound.
- Storms throw lightning: a flash of light, then thunder delayed by the strike's distance.
- Particles can be drawn as streaks along their velocity: a new emitter field, `stretch`, in seconds of motion.
- New sounds (generated, recorded in `data/sounds/CREDITS.md`): rain_loop, thunder and sandstorm_loop.

## Capabilities

### New Capabilities
- `weather`: spells of rain, storms, snow and sandstorms, and how they show.

## Impact

`engine/src/fx/particles.{c,h}`, `engine/src/gfx/gl_pipeline.c`, `engine/src/script/lua_gfx.c`; new
`data/scripts/weather.lua`; `data/scripts/main.lua`; three new sounds. New tests: `tests/game/weather.lua` and
`tests/lua/weather_test.lua`. The `nav_arrival_2` golden changes on purpose: it now shows a dry world in a sandstorm.
