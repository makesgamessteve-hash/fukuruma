# Proposal

## Why

Stations and the Jump Ship stood still above the range, but dolls in orbit go round their world (CONCEPT §2.2: "from
the surface it is a bright fast star"). With real orbits, the Drop Ship has to fly to wherever the station is,
including the far side of the world.

## What Changes

- **Orbit controller** (Space Station, Jump Ship): a circle around the world's centre in the plane over the range,
  starting overhead. Its angle advances by sqrt(GM / r^3) × dt every tick, with GM from the world's gravity and radius,
  whether anyone is aboard or not. The station at 400 km goes round in about 1.5 hours, and the Jump Ship at
  30,000 km in many hours.
- **Flying dolls measure their height from the world's centre:**
  - their floor over the ground below them;
  - their top speed, which grows with height (now 1× per km, up to 15 km/s);

  so they can follow the world's curve.
- **Flying dolls on autopilot** make a transfer around the world's centre. The distance from the centre and the angle
  around it both close in on the target's at top speed, using arithmetic only. That covers the climb to a station
  wherever it is, including round on the far side, and the way back down.

## Capabilities

### Modified Capabilities
- `travel`: dolls in orbit go round their world, and flying autopilots reach them wherever they are.

## Impact

Changed: `data/scripts/chain.lua`, `data/scripts/dolls/{space_station,jump_ship}.lua` and `data/scripts/dolls.lua`.
`tests/lua/chain_test.lua` is updated. The travel, Fukuruma and drive goldens and the recorded hashes change on
purpose.
