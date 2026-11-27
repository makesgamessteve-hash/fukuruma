# Proposal

## Why

The universe starts with the galaxy (CONCEPT §4.1): its stars are generated on demand per sector from the galaxy
seed, so the sky is real (every star seen can be jumped to) and the same seed gives the same stars everywhere.

## What Changes

- **Deterministic exp, log, atan2 and pow** (`core/dmath.c`, fdlibm kernels), as the plan's generation rule asks.
- **Galaxy** (`gen/galaxy.c`): a density model (exponential disk with the Sun at 26,000 ly, four logarithmic arms
  with a 12 degree pitch, a bulge), 32 ly sectors whose star counts follow it (the core thinned to 4096 per sector),
  seeds by hierarchical hashing (galaxy, sector, star), Kroupa masses, and white dwarfs, neutron stars, black holes,
  brown dwarfs, giants and rogue planets in plausible shares.
- **Star physics:** luminosity and radius from mass, temperature by Stefan-Boltzmann, black-body colour, spectral
  class.
- **Scripts:** `fk.galaxy.sector`, `request` (background, through the job system), `density`, `physics`, `SECTOR`,
  `HOME`; `fk.math.exp`, `log`, `atan2`, `pow`; `fk/galaxy.lua` with cached sectors, stars near a point and the home
  star.

## Capabilities

### New Capabilities
- `galaxy-generation`: density, sectors, stars, physics, determinism.

## Impact

`engine/src/gen/galaxy.{c,h}`, `engine/src/core/dmath.{c,h}`, `engine/src/script/{lua_galaxy,lua_orbit,script}.c`,
`data/scripts/fk/galaxy.lua`; tests `test_galaxy.c`, `test_orbit.c`, `galaxy_test.lua`.
