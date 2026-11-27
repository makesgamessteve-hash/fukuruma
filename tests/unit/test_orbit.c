#include <math.h>
#include <stdint.h>
#include <string.h>

#include "core/dmath.h"
#include "core/orbit.h"
#include "utest.h"

static uint64_t bits(double x) {
    uint64_t u;
    memcpy(&u, &x, sizeof u);
    return u;
}

UTEST(dmath, close_to_the_c_library) {
    double worst = 0;
    for (int k = -200000; k <= 200000; k++) {
        double x = k * 0.000731;
        worst = fmax(worst, fmax(fabs(fk_dsin(x) - sin(x)), fabs(fk_dcos(x) - cos(x))));
    }
    EXPECT_LT(worst, 3e-16);
    EXPECT_LT(fabs(fk_dsin(98765.4321) - sin(98765.4321)), 1e-12);
    EXPECT_LT(fabs(fk_dcos(3.3e7) - cos(3.3e7)), 1e-8); /* beyond 1e6: wrapped first, still close */
    EXPECT_EQ(fk_dsin(0.0), 0.0);
    EXPECT_EQ(fk_dcos(0.0), 1.0);
    EXPECT_TRUE(isnan(fk_dsin(NAN)) && isnan(fk_dcos(INFINITY)));
    EXPECT_LT(fabs(fk_dwrap(3 * FK_PI) + FK_PI), 1e-15);
    EXPECT_EQ(fk_dwrap(1.0), 1.0);
}

UTEST(dmath, recorded_bits) {
    /* Recorded once; every platform must produce exactly these doubles. */
    EXPECT_EQ(bits(fk_dsin(1.0)), 0x3feaed548f090ceeull);
    EXPECT_EQ(bits(fk_dcos(2.5)), 0xbfe9a2f7ef858b7dull);
    EXPECT_EQ(bits(fk_dsin(-1234.5678)), 0xbfb3fa00084ee3ddull);
}

UTEST(orbit, kepler_equation) {
    const double es[] = {0, 0.1, 0.5, 0.9, 0.999};
    for (int i = 0; i < 5; i++)
        for (double m = -3.1; m < 3.1; m += 0.05) {
            double E = fk_kepler(m, es[i]);
            ASSERT_LT(fabs(E - es[i] * sin(E) - m), 1e-13);
        }
    EXPECT_LT(fabs(fk_kepler(FK_TAU + 0.5, 0) - 0.5), 1e-15); /* the mean anomaly is wrapped */
}

static double dot(const double a[3], const double b[3]) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }

UTEST(orbit, circular_and_elliptic) {
    const double mu = 3.986004418e14, a = 7e6;
    fk_orbit circle = {a, 0, 0, 0, 0, 0, 0, mu};
    ASSERT_TRUE(fk_orbit_check(&circle) == NULL);
    double p[3], v[3];
    fk_orbit_state(&circle, 0, p, v);
    EXPECT_LT(fabs(p[0] - a), 1e-6);
    EXPECT_LT(fabs(sqrt(dot(v, v)) - sqrt(mu / a)), 1e-9);
    double h = p[2] * v[0] - p[0] * v[2]; /* y of r x v: counter-clockwise seen from +y */
    EXPECT_GT(h, 0);
    double T = fk_orbit_period(&circle), q[3], w[3];
    fk_orbit_state(&circle, T / 4, q, w);
    EXPECT_LT(fabs(q[2] + a), 1e-3); /* a quarter later it is at -z */
    fk_orbit_state(&circle, T, q, w);
    EXPECT_LT(fabs(q[0] - p[0]) + fabs(q[2] - p[2]), 1e-3); /* and back after one period */

    fk_orbit ellipse = {2.4e7, 0.7, 0.9, 1.2, 2.1, 0.3, 100, mu};
    for (double t = 0; t < 1e5; t += 777) {
        fk_orbit_state(&ellipse, t, p, v);
        double r = sqrt(dot(p, p));
        ASSERT_LT(fabs(dot(v, v) / 2 - mu / r + mu / (2 * ellipse.a)), 1e-3); /* the vis-viva energy */
        ASSERT_TRUE(r >= ellipse.a * (1 - ellipse.e) - 1e-3 && r <= ellipse.a * (1 + ellipse.e) + 1e-3);
    }
    fk_orbit polar = {a, 0, FK_PI / 2, 0, FK_PI / 2, 0, 0, mu};
    fk_orbit_state(&polar, 0, p, v);
    EXPECT_LT(fabs(p[1] - a), 1e-6); /* a polar orbit reaches the north */
}

UTEST(orbit, checks_the_elements) {
    fk_orbit o = {7e6, 0, 0, 0, 0, 0, 0, 1};
    o.a = -1;
    EXPECT_STREQ(fk_orbit_check(&o), "the semi-major axis must be above 0");
    o.a = 1, o.e = 1;
    EXPECT_STREQ(fk_orbit_check(&o), "the eccentricity must be from 0 to below 1");
    o.e = 0, o.mu = 0;
    EXPECT_STREQ(fk_orbit_check(&o), "mu must be above 0");
    o.mu = 1, o.i = NAN;
    EXPECT_STREQ(fk_orbit_check(&o), "the elements must be finite numbers");
}

UTEST(dmath, exp_log_atan2_pow) {
    double worst = 0;
    for (double x = -700; x < 700; x += 0.731) worst = fmax(worst, fabs(fk_dexp(x) / exp(x) - 1));
    EXPECT_LT(worst, 1e-15);
    worst = 0;
    for (double x = 1e-300; x < 1e300; x *= 3.7) worst = fmax(worst, fabs(fk_dlog(x) - log(x)) / fmax(1, fabs(log(x))));
    EXPECT_LT(worst, 1e-15);
    worst = 0;
    for (double a = -3.1; a < 3.1; a += 0.0137)
        for (double r = 0.5; r < 100; r *= 3) worst = fmax(worst, fabs(fk_datan2(r * sin(a), r * cos(a)) - atan2(r * sin(a), r * cos(a))));
    EXPECT_LT(worst, 1e-15);
    EXPECT_LT(fabs(fk_dpow(2.5, 3.5) - pow(2.5, 3.5)), 1e-13);
    EXPECT_EQ(fk_dpow(0, 2), 0.0);
    EXPECT_TRUE(isinf(fk_dpow(0, -1)));
    EXPECT_TRUE(isinf(fk_dexp(800)) && fk_dexp(-800) == 0 && isnan(fk_dexp(NAN)));
    EXPECT_TRUE(isnan(fk_dlog(-1)) && isinf(fk_dlog(0)) && isinf(fk_dlog(INFINITY)) && isnan(fk_dlog(NAN)));
    EXPECT_EQ(fk_datan2(1, 0), FK_PI / 2);
    EXPECT_EQ(fk_datan2(-1, 0), -FK_PI / 2);
    EXPECT_EQ(fk_datan2(0, 0), 0.0);
    EXPECT_TRUE(isnan(fk_datan2(NAN, 1)));
    EXPECT_LT(fabs(fk_datan2(0, -1) - FK_PI), 1e-15);
    EXPECT_LT(fabs(fk_datan2(-1e-9, -1) + FK_PI), 1e-8);
}
