## Purpose

Generates the galaxy's stars on demand, per sector, from the galaxy seed: the same seed gives the same stars on
every platform, and every star in the sky is a real place.

## ADDED Requirements

### Requirement: Galaxy density
The galaxy SHALL have a disk, spiral arms and a central bulge: about 0.004 stars per cubic light-year near the Sun's
distance, many times more in the core, and far fewer high above the disk or beyond its edge.

#### Scenario: Arms and gaps
- **WHEN** the density is sampled around the circle at the Sun's distance from the centre
- **THEN** the densest point has more than 2.5 times the density of the thinnest

### Requirement: Sectors of stars
Stars SHALL be generated per 32 ly sector from the sector's seed, each with its own seed, position, kind (star, white
dwarf, neutron star, black hole, brown dwarf, giant, rogue planet), mass, radius, luminosity, temperature, black-body
colour and spectral class. Most stars SHALL be red dwarfs. Sectors SHALL also be generated in the background.

#### Scenario: A real neighbourhood
- **WHEN** 40 sectors near the Sun's distance are generated
- **THEN** most main-sequence stars are cooler than 3700 K, and white and brown dwarfs appear in plausible shares

#### Scenario: Same stars everywhere
- **WHEN** five recorded sectors are generated on Linux, Windows or macOS
- **THEN** their stars hash to the recorded value

### Requirement: Star physics
A star's luminosity, radius, temperature and colour SHALL follow from its kind and mass.

#### Scenario: The Sun
- **WHEN** a main-sequence star of one solar mass is described
- **THEN** it has one solar luminosity and radius, a temperature of 5772 K and spectral class G
