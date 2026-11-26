#include "core/orbit.h"

#include <math.h>
#include <stddef.h>

#include "core/dmath.h"

const char *fk_orbit_check(const fk_orbit *o) {
    const double *all[] = {&o->a, &o->e, &o->i, &o->node, &o->periapsis, &o->anomaly, &o->epoch, &o->mu};
    for (int k = 0; k < 8; k++)
        if (!isfinite(*all[k])) return "the elements must be finite numbers";
    if (!(o->a > 0)) return "the semi-major axis must be above 0";
    if (!(o->e >= 0 && o->e < 1)) return "the eccentricity must be from 0 to below 1";
    if (!(o->mu > 0)) return "mu must be above 0";
    return NULL;
}

static double mean_motion(const fk_orbit *o) { return sqrt(o->mu / (o->a * o->a * o->a)); }

double fk_orbit_period(const fk_orbit *o) { return FK_TAU / mean_motion(o); }

double fk_kepler(double mean, double e) {
    double m = fk_dwrap(mean), E = e < 0.8 ? m : (m < 0 ? -FK_PI : FK_PI);
    for (int k = 0; k < 50; k++) { /* converges in a few steps; the cap keeps the cost bounded */
        double s, c;
        fk_dsincos(E, &s, &c);
        double step = (E - e * s - m) / (1 - e * c);
        E -= step;
        if (fabs(step) < 1e-15) break;
    }
    return E;
}

/* Rotates perifocal (x towards periapsis, y along the motion) into the reference frame: Rz(node) Rx(i) Rz(w), with
   the usual z-north axes mapped to this engine's y-up axes as (X, Y, Z) -> (X, Z, -Y). */
static void to_reference(const fk_orbit *o, const double in[2], double out[3]) {
    double so, co, si, ci, sw, cw;
    fk_dsincos(o->node, &so, &co);
    fk_dsincos(o->i, &si, &ci);
    fk_dsincos(o->periapsis, &sw, &cw);
    double x1 = cw * in[0] - sw * in[1], y1 = sw * in[0] + cw * in[1]; /* Rz(w) */
    double y2 = ci * y1, z2 = si * y1;                                 /* Rx(i) */
    double X = co * x1 - so * y2, Y = so * x1 + co * y2;               /* Rz(node) */
    out[0] = X, out[1] = z2, out[2] = -Y;
}

void fk_orbit_state(const fk_orbit *o, double t, double p[3], double v[3]) {
    double n = mean_motion(o), E = fk_kepler(o->anomaly + n * (t - o->epoch), o->e), s, c;
    fk_dsincos(E, &s, &c);
    double b = o->a * sqrt(1 - o->e * o->e), k = n / (1 - o->e * c);
    double pp[2] = {o->a * (c - o->e), b * s}, vv[2] = {-o->a * s * k, b * c * k};
    to_reference(o, pp, p);
    to_reference(o, vv, v);
}
