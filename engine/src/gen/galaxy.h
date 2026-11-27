/* The galaxy (CONCEPT 4.1): a density function and the stars of each sector, generated on demand from the galaxy
   seed by hierarchical hashing (galaxy -> sector -> star). Deterministic: integer hashing, IEEE arithmetic and the
   core/dmath.h functions only. Positions are in light-years from the galactic centre; the disk lies in the x-z plane
   with +y towards galactic north. */
#pragma once
#include <stdint.h>

#define FK_SECTOR_LY 32.0        /* edge of a sector cube */
#define FK_SECTOR_MAX_STARS 4096 /* the dense core is thinned to this */

enum { FK_STAR, FK_WHITE_DWARF, FK_NEUTRON_STAR, FK_BLACK_HOLE, FK_BROWN_DWARF, FK_GIANT, FK_ROGUE_PLANET, FK_STAR_KINDS };

typedef struct {
    uint64_t seed;     /* the star's own seed: its system is generated from it */
    double pos[3];     /* light-years */
    int kind;          /* FK_STAR ... */
    double mass;       /* solar masses (Earth masses / 333000 for rogue planets) */
    double radius;     /* solar radii */
    double luminosity; /* solar luminosities */
    double temperature;/* kelvin */
    float color[3];    /* linear RGB of the black body, brightest channel 1 */
} fk_star;

/* Stars per cubic light-year at a point (about 0.004 near the Sun). */
double fk_galaxy_density(const double p[3]);
/* The seed of a sector. */
uint64_t fk_sector_seed(uint64_t galaxy_seed, int64_t sx, int64_t sy, int64_t sz);
/* Generates a sector's stars into out (room for FK_SECTOR_MAX_STARS); returns how many. */
int fk_galaxy_sector(uint64_t galaxy_seed, int64_t sx, int64_t sy, int64_t sz, fk_star *out);
/* Fills radius, luminosity, temperature and colour from kind and mass (seed varies giants and remnants). */
void fk_star_physics(fk_star *s);
/* Black-body colour of a temperature: linear RGB, brightest channel 1. */
void fk_blackbody(double kelvin, float rgb[3]);
/* Where the Sun would be: the home position for a new game. */
extern const double FK_GALAXY_HOME[3];
