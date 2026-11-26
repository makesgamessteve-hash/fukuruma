# Proposal

## Why

Planets, moons, stations and parked vessels move on rails (plan §3.3): Kepler orbits solved from their elements at
any time, not integrated step by step, so they stay exact over years of game time and cost almost nothing. Their
positions are simulation state, so they must be the same on every platform; the C library's `sin` and `cos` are
not guaranteed to be.

## What Changes

- **Deterministic trigonometry** (`core/dmath.c`): `fk_dsin`, `fk_dcos`, `fk_dwrap` from fdlibm's polynomial
  kernels with Cody-Waite reduction: only arithmetic and `floor`, within about 1 ulp. Lua: `fk.math.sin`, `cos`,
  `wrap`, `pi`.
- **Kepler orbits** (`core/orbit.c`): elliptic elements (a, e, i, node, periapsis, mean anomaly at an epoch, mu),
  Newton's method on the eccentric anomaly, position and velocity relative to the central body; x-z is the
  reference plane, +y north. Lua: `fk.orbit.state(elements, t)`, `fk.orbit.period(elements)`.
- **Motion on rails in the frame tree:** `frames.orbit(id, elements)` and `frames.spin(id, axis, rate, phase)`
  store the `orbit` and `spin` components; `frames.update(t)` places those frames for the simulation time.
- **Scale ladder:** the planet orbits the star (e = 0.0167), the ship orbits the planet, and the planet's surface
  turns once a sidereal day; a new `orbits` scenario checks the period, the return after one orbit, the turning,
  and a recorded state hash a year later.

## Capabilities

### New Capabilities
- `orbital-mechanics`: deterministic trigonometry, Kepler orbits, motion on rails.

## Impact

`engine/src/core/{dmath,orbit}.{c,h}`, `engine/src/script/lua_orbit.c`, `script.c/h`; `fk/frames.lua`,
`scale_ladder.lua`; `THIRD_PARTY_NOTICES.md` (fdlibm); tests `test_orbit.c`, `orbit_test.lua`,
`scale_ladder_test.lua`, `tests/game/orbits.lua`, `tests/game/scale_ladder.lua` (goldens regenerated on purpose:
the bodies now stand on their orbits).
