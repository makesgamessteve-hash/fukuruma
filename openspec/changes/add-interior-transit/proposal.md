# Proposal

## Why

The hangars of the big dolls are as long as what they hold: the Jump Ship's hangar for the Space Station is about
40 km long. Plan M8 asks for interior transit and ambient drones. Its game test walks from the Jump Ship's bridge to
a station hangar by tram and into the docked station.

## What Changes

- **Trams.** A doll with hangars gets a tram: one stop where the corridor ends, and one beside each docked doll's
  ramp. Each ramp now stands at the near end of its docked doll, not at the hangar's door. F at a stop rides to the
  next stop, in a few seconds (at least 40 m/s). The rider gets off beside the stop. The hand does nothing during the
  ride. The ride is part of the saved walk.
- **Drones.** Two ambient drones circle in each drone bay and hangar, with blinking lights. They are presentation
  only.
- **Lighting.** Hangar lights scale with the hangar's size. While walking, the planetary depth slice starts where the
  local slice ends, so kilometre-long hangars are drawn even in orbit.
- **Game test** `hangars`: from the Jump Ship's bridge down the corridor, by tram to the Space Station's hangar, up
  its ramp, to its bridge, and launching it from there.

## Capabilities

### Modified Capabilities
- `vessel-interiors`: trams and drones.

## Impact

Changed: `data/scripts/{interior,chain,main,feedback}.lua`. Extended: `tests/lua/interior_test.lua`. New:
`tests/game/hangars.lua`, a slow scenario, with its goldens. The 50 streamed sectors in the plan's test are not
included: the layouts are fixed per doll kind, so there is nothing to stream.
