#include "gen/galaxy.h"

#include <math.h>

#include "core/dmath.h"
#include "core/rng.h"

#define R_SUN 26000.0 /* the Sun's distance from the centre, light-years */

const double FK_GALAXY_HOME[3] = {R_SUN, 20.0, 0.0};

double fk_galaxy_density(const double p[3]) {
    double R = sqrt(p[0] * p[0] + p[2] * p[2]), r = sqrt(R * R + p[1] * p[1]);
    double disk = fk_dexp(-(R - R_SUN) / 9000.0) * fk_dexp(-fabs(p[1]) / 1000.0);
    if (R > 70000.0) disk *= fk_dexp(-(R - 70000.0) / 2000.0);
    /* four logarithmic arms, pitch 12 degrees: denser on the arms, thinner between them */
    double theta = fk_datan2(p[2], p[0]), phase = 4.0 * (theta - fk_dlog((R > 1 ? R : 1) / 4000.0) / 0.21255656167002213);
    double arm = 0.5 * (fk_dcos(phase) + 1.0);
    double spiral = 0.6 + 0.8 * arm * arm * arm * 2.0;
    double bulge = 40.0 * fk_dexp(-(r / 2500.0) * (r / 2500.0));
    return 0.004 * (disk * spiral + bulge);
}

uint64_t fk_sector_seed(uint64_t galaxy_seed, int64_t sx, int64_t sy, int64_t sz) {
    uint64_t h = fk_hash_u64(FK_HASH_INIT, galaxy_seed);
    h = fk_hash_bytes(h, "sector", 6);
    h = fk_hash_u64(h, (uint64_t)sx);
    h = fk_hash_u64(h, (uint64_t)sy);
    h = fk_hash_u64(h, (uint64_t)sz);
    return fk_mix64(h);
}

void fk_blackbody(double kelvin, float rgb[3]) { /* Tanner Helland's fit, then to linear light */
    double t = kelvin / 100.0, c[3];
    if (kelvin <= 0) {
        rgb[0] = rgb[1] = rgb[2] = 0;
        return;
    }
    c[0] = t <= 66 ? 255 : 329.698727446 * fk_dpow(t - 60, -0.1332047592);
    c[1] = t <= 66 ? 99.4708025861 * fk_dlog(t) - 161.1195681661 : 288.1221695283 * fk_dpow(t - 60, -0.0755148492);
    c[2] = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * fk_dlog(t - 10) - 305.0447927307;
    double top = 0;
    for (int i = 0; i < 3; i++) {
        c[i] = c[i] < 0 ? 0 : c[i] > 255 ? 1 : c[i] / 255;
        c[i] = c[i] > 0 ? fk_dpow(c[i], 2.2) : 0;
        if (c[i] > top) top = c[i];
    }
    for (int i = 0; i < 3; i++) rgb[i] = (float)(top > 0 ? c[i] / top : 0);
}

static double stefan(double radius, double temperature) { /* luminosity from radius and temperature */
    double t = temperature / 5772.0;
    return radius * radius * t * t * t * t;
}

void fk_star_physics(fk_star *s) {
    fk_rng r;
    fk_rng_seed(&r, s->seed ^ 0x9e3779b97f4a7c15ull);
    double m = s->mass, u = fk_rng_float(&r);
    switch (s->kind) {
    case FK_STAR:
        s->luminosity = m < 0.43 ? 0.23 * fk_dpow(m, 2.3) : m < 2 ? m * m * m * m : m < 55 ? 1.4 * fk_dpow(m, 3.5) : 32000 * m;
        s->radius = m < 1 ? fk_dpow(m, 0.8) : fk_dpow(m, 0.57);
        s->temperature = 5772.0 * fk_dpow(s->luminosity / (s->radius * s->radius), 0.25);
        break;
    case FK_WHITE_DWARF:
        s->radius = 0.0126 * fk_dpow(m, -1.0 / 3.0);
        s->temperature = 4000 + 26000 * u;
        s->luminosity = stefan(s->radius, s->temperature);
        break;
    case FK_NEUTRON_STAR:
        s->radius = 1.4e-5, s->temperature = 6e5;
        s->luminosity = stefan(s->radius, s->temperature);
        break;
    case FK_BLACK_HOLE:
        s->radius = 4.24e-6 * m, s->temperature = 0, s->luminosity = 0;
        break;
    case FK_BROWN_DWARF:
        s->radius = 0.1, s->temperature = 600 + 2000 * (m - 0.013) / 0.062;
        s->luminosity = stefan(s->radius, s->temperature);
        break;
    case FK_GIANT:
        s->radius = 10 + 90 * u, s->temperature = 3600 + 1200 * fk_rng_float(&r);
        s->luminosity = stefan(s->radius, s->temperature);
        break;
    default: /* a rogue planet: no light of its own */
        s->radius = 1e-3 * fk_dpow(m / 3.0e-6, 0.3), s->temperature = 40, s->luminosity = 0;
        break;
    }
    fk_blackbody(s->temperature, s->color);
}

/* Kroupa's initial mass function: dN/dm ~ m^-1.3 from 0.08 to 0.5, m^-2.3 from 0.5 to 150 solar masses. */
static double imf(fk_rng *r) {
    static const double LO = 0.08, MID = 0.5, HI = 150;
    double i1 = (fk_dpow(MID, -0.3) - fk_dpow(LO, -0.3)) / -0.3, i2 = 0.5 * (fk_dpow(HI, -1.3) - fk_dpow(MID, -1.3)) / -1.3;
    double u = fk_rng_float(r), v = fk_rng_float(r);
    double lo = u < i1 / (i1 + i2) ? LO : MID, hi = lo == LO ? MID : HI, k = lo == LO ? -0.3 : -1.3;
    double a = fk_dpow(lo, k), b = fk_dpow(hi, k);
    return fk_dpow(a + v * (b - a), 1.0 / k);
}

int fk_galaxy_sector(uint64_t galaxy_seed, int64_t sx, int64_t sy, int64_t sz, fk_star *out) {
    uint64_t seed = fk_sector_seed(galaxy_seed, sx, sy, sz);
    fk_rng r;
    fk_rng_seed(&r, seed);
    double corner[3] = {(double)sx * FK_SECTOR_LY, (double)sy * FK_SECTOR_LY, (double)sz * FK_SECTOR_LY}, centre[3];
    for (int k = 0; k < 3; k++) centre[k] = corner[k] + FK_SECTOR_LY / 2;
    double expected = fk_galaxy_density(centre) * FK_SECTOR_LY * FK_SECTOR_LY * FK_SECTOR_LY;
    double u1 = fk_rng_float(&r), u2 = fk_rng_float(&r);
    double gauss = sqrt(-2.0 * fk_dlog(u1 > 1e-300 ? u1 : 1e-300)) * fk_dcos(FK_TAU * u2); /* Box-Muller */
    double count = floor(expected + gauss * sqrt(expected) + 0.5);
    int n = count < 0 ? 0 : count > FK_SECTOR_MAX_STARS ? FK_SECTOR_MAX_STARS : (int)count;
    for (int i = 0; i < n; i++) {
        fk_star *s = &out[i];
        s->seed = fk_mix64(fk_hash_u64(seed, (uint64_t)i));
        fk_rng sr;
        fk_rng_seed(&sr, s->seed);
        for (int k = 0; k < 3; k++) s->pos[k] = corner[k] + fk_rng_float(&sr) * FK_SECTOR_LY;
        double kind = fk_rng_float(&sr);
        if (kind < 0.02) s->kind = FK_ROGUE_PLANET, s->mass = 3.0e-6 * (0.1 + 9.9 * fk_rng_float(&sr));
        else if (kind < 0.12) s->kind = FK_BROWN_DWARF, s->mass = 0.013 + 0.062 * fk_rng_float(&sr);
        else if (kind < 0.18) s->kind = FK_WHITE_DWARF, s->mass = 0.5 + 0.7 * fk_rng_float(&sr);
        else if (kind < 0.183) s->kind = FK_NEUTRON_STAR, s->mass = 1.2 + 0.8 * fk_rng_float(&sr);
        else if (kind < 0.1833) s->kind = FK_BLACK_HOLE, s->mass = 5 + 15 * fk_rng_float(&sr);
        else if (kind < 0.193) s->kind = FK_GIANT, s->mass = 1 + 3 * fk_rng_float(&sr);
        else s->kind = FK_STAR, s->mass = imf(&sr);
        fk_star_physics(s);
    }
    return n;
}
