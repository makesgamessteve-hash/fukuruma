#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "core/rng.h"
#include "gen/galaxy.h"
#include "utest.h"

UTEST(galaxy, density_follows_disk_arms_and_bulge) {
    const double home[3] = {26000, 0, 0}, core[3] = {0, 0, 0}, high[3] = {26000, 4000, 0}, far[3] = {90000, 0, 0};
    double d = fk_galaxy_density(home);
    EXPECT_GT(d, 0.002);
    EXPECT_LT(d, 0.01);
    EXPECT_GT(fk_galaxy_density(core), 20 * d);
    EXPECT_LT(fk_galaxy_density(high), 0.05 * d);
    EXPECT_LT(fk_galaxy_density(far), 1e-3 * d);
    double lo = 1e9, hi = 0; /* around the circle at the Sun's distance: arms and gaps */
    for (int i = 0; i < 360; i++) {
        double a = i * 3.14159265358979 / 180, p[3] = {26000 * cos(a), 0, 26000 * sin(a)};
        double v = fk_galaxy_density(p);
        lo = v < lo ? v : lo, hi = v > hi ? v : hi;
    }
    EXPECT_GT(hi / lo, 2.5);
}

static uint64_t sector_hash(uint64_t seed, int64_t sx, int64_t sy, int64_t sz, int *count) {
    fk_star *stars = malloc(FK_SECTOR_MAX_STARS * sizeof *stars);
    int n = fk_galaxy_sector(seed, sx, sy, sz, stars);
    uint64_t h = FK_HASH_INIT;
    for (int i = 0; i < n; i++) {
        h = fk_hash_u64(h, stars[i].seed);
        h = fk_hash_bytes(h, stars[i].pos, sizeof stars[i].pos);
        h = fk_hash_u64(h, (uint64_t)stars[i].kind);
        h = fk_hash_bytes(h, &stars[i].mass, sizeof stars[i].mass);
        h = fk_hash_bytes(h, &stars[i].luminosity, sizeof stars[i].luminosity);
        h = fk_hash_bytes(h, &stars[i].temperature, sizeof stars[i].temperature);
        h = fk_hash_bytes(h, stars[i].color, sizeof stars[i].color);
    }
    free(stars);
    *count = n;
    return h;
}

UTEST(galaxy, sectors_are_deterministic) {
    int n, m;
    uint64_t a = sector_hash(42, 812, 0, 0, &n), b = sector_hash(42, 812, 0, 0, &m);
    EXPECT_EQ(a, b);
    EXPECT_GT(n, 40);
    EXPECT_LT(n, 400);
    EXPECT_NE(sector_hash(43, 812, 0, 0, &m), a); /* another galaxy */
    EXPECT_NE(sector_hash(42, 813, 0, 0, &m), a); /* another sector */
    uint64_t h = FK_HASH_INIT;
    for (int i = -2; i <= 2; i++) h = fk_hash_u64(h, sector_hash(7, 812 + i, i, -i, &m));
    /* Recorded once; every platform must generate exactly these stars. */
    EXPECT_EQ(h, 0x4a77f80baf17e771ull);
    int core;
    sector_hash(7, 0, 0, 0, &core);
    EXPECT_EQ(core, FK_SECTOR_MAX_STARS); /* the dense core is thinned */
}

UTEST(galaxy, stars_look_like_a_real_neighbourhood) {
    fk_star *stars = malloc(FK_SECTOR_MAX_STARS * sizeof *stars);
    int kinds[FK_STAR_KINDS] = {0}, total = 0, m_dwarfs = 0, mains = 0;
    for (int s = 0; s < 40; s++) {
        int n = fk_galaxy_sector(1, 800 + s, 0, 5, stars);
        for (int i = 0; i < n; i++) {
            const fk_star *t = &stars[i];
            kinds[t->kind]++, total++;
            ASSERT_TRUE(t->pos[0] >= (800 + s) * FK_SECTOR_LY && t->pos[0] < (801 + s) * FK_SECTOR_LY);
            if (t->kind == FK_STAR) {
                mains++;
                if (t->temperature < 3700) m_dwarfs++;
                ASSERT_TRUE(t->mass >= 0.08 && t->mass <= 150);
            }
            ASSERT_TRUE(t->color[0] <= 1 && t->color[1] <= 1 && t->color[2] <= 1);
        }
    }
    EXPECT_GT(total, 2000);
    EXPECT_GT((double)m_dwarfs / mains, 0.55); /* most stars are red dwarfs */
    EXPECT_LT((double)kinds[FK_WHITE_DWARF] / total, 0.09);
    EXPECT_GT((double)kinds[FK_BROWN_DWARF] / total, 0.06);
    free(stars);
}

UTEST(galaxy, star_physics) {
    fk_star sun = {.kind = FK_STAR, .mass = 1};
    fk_star_physics(&sun);
    EXPECT_NEAR(sun.luminosity, 1, 1e-9);
    EXPECT_NEAR(sun.radius, 1, 1e-9);
    EXPECT_NEAR(sun.temperature, 5772, 1e-6);
    EXPECT_GT(sun.color[0], 0.9f); /* white-yellow */
    EXPECT_GT(sun.color[2], 0.5f);
    const int kinds[] = {FK_STAR, FK_STAR, FK_STAR, FK_WHITE_DWARF, FK_NEUTRON_STAR, FK_BLACK_HOLE, FK_BROWN_DWARF, FK_GIANT, FK_ROGUE_PLANET};
    const double masses[] = {0.2, 10, 80, 0.6, 1.4, 10, 0.05, 2, 3e-6};
    for (int i = 0; i < 9; i++) {
        fk_star s = {.kind = kinds[i], .mass = masses[i], .seed = 99};
        fk_star_physics(&s);
        EXPECT_TRUE(s.radius > 0 && s.luminosity >= 0 && s.temperature >= 0);
    }
    fk_star hot = {.kind = FK_STAR, .mass = 20}, red = {.kind = FK_STAR, .mass = 0.15};
    fk_star_physics(&hot);
    fk_star_physics(&red);
    EXPECT_GT(hot.color[2], hot.color[0]); /* blue */
    EXPECT_GT(red.color[0], red.color[2] * 3); /* red */
    float black[3];
    fk_blackbody(0, black);
    EXPECT_EQ(black[0], 0.0f);
    fk_blackbody(1500, black); /* too cool for blue */
    EXPECT_EQ(black[2], 0.0f);
}
