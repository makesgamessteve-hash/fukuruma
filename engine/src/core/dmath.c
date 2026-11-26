/* The polynomial kernels and reduction constants are from fdlibm (see THIRD_PARTY_NOTICES.md):
 * ====================================================
 * Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
 *
 * Developed at SunSoft, a Sun Microsystems, Inc. business.
 * Permission to use, copy, modify, and distribute this
 * software is freely granted, provided that this notice
 * is preserved.
 * ====================================================
 */
#include "core/dmath.h"

#include <math.h>

/* sin and cos on [-pi/4, pi/4]. */
static double kernel_sin(double x) {
    const double S1 = -1.66666666666666324348e-01, S2 = 8.33333333332248946124e-03, S3 = -1.98412698298579493134e-04,
                 S4 = 2.75573137070700676789e-06, S5 = -2.50507602534068634195e-08, S6 = 1.58969099521155010221e-10;
    double z = x * x, v = z * x, r = S2 + z * (S3 + z * (S4 + z * (S5 + z * S6)));
    return x + v * (S1 + z * r);
}

static double kernel_cos(double x) {
    const double C1 = 4.16666666666666019037e-02, C2 = -1.38888888888741095749e-03, C3 = 2.48015872894767294178e-05,
                 C4 = -2.75573143513906633035e-07, C5 = 2.08757232129817482790e-09, C6 = -1.13596475577881948265e-11;
    double z = x * x, r = z * (C1 + z * (C2 + z * (C3 + z * (C4 + z * (C5 + z * C6)))));
    double hz = 0.5 * z, w = 1.0 - hz;
    return w + (((1.0 - w) - hz) + z * r);
}

double fk_dwrap(double x) { return x - FK_TAU * floor((x + FK_PI) / FK_TAU); }

/* x = n * pi/2 + y with |y| <= pi/4 (pi/2 in three parts: n * part is exact for |n| < 2^20). */
static int reduce(double x, double *y) {
    const double INV_PIO2 = 6.36619772367581382433e-01, PIO2_1 = 1.57079632673412561417e+00,
                 PIO2_2 = 6.07710050630396597660e-11, PIO2_2T = 2.02226624879595063154e-21;
    if (!(fabs(x) <= 1e6)) x = fk_dwrap(x); /* NaN and infinities stay NaN */
    double n = floor(x * INV_PIO2 + 0.5);
    *y = ((x - n * PIO2_1) - n * PIO2_2) - n * PIO2_2T;
    return (int)(n - 4.0 * floor(n / 4.0)); /* the quadrant, 0..3 */
}

void fk_dsincos(double x, double *s, double *c) {
    double y;
    int q = x == x ? reduce(x, &y) : (y = x, 0);
    double sy = kernel_sin(y), cy = kernel_cos(y);
    switch (q) {
    case 0: *s = sy, *c = cy; break;
    case 1: *s = cy, *c = -sy; break;
    case 2: *s = -sy, *c = -cy; break;
    default: *s = -cy, *c = sy; break;
    }
}

double fk_dsin(double x) {
    double s, c;
    fk_dsincos(x, &s, &c);
    return s;
}

double fk_dcos(double x) {
    double s, c;
    fk_dsincos(x, &s, &c);
    return c;
}
