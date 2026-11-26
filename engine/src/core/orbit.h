/* Kepler orbits on rails: the position and velocity of a body on an elliptic orbit at a time, relative to the
   body it orbits. Deterministic (core/dmath.h). The reference plane is x-z with +y north; orbits with an
   inclination of 0 run counter-clockwise seen from +y. */
#pragma once
#include <stdbool.h>

typedef struct {
    double a;         /* semi-major axis, metres (> 0) */
    double e;         /* eccentricity, 0 <= e < 1 */
    double i;         /* inclination, radians */
    double node;      /* longitude of the ascending node, radians */
    double periapsis; /* argument of periapsis, radians */
    double anomaly;   /* mean anomaly at the epoch, radians */
    double epoch;     /* seconds */
    double mu;        /* gravitational parameter of the central body, m^3/s^2 (> 0) */
} fk_orbit;

/* NULL when the elements describe an elliptic orbit, else what is wrong. */
const char *fk_orbit_check(const fk_orbit *o);
double fk_orbit_period(const fk_orbit *o);
/* The eccentric anomaly for a mean anomaly (Newton's method). */
double fk_kepler(double mean, double e);
void fk_orbit_state(const fk_orbit *o, double t, double p[3], double v[3]);
