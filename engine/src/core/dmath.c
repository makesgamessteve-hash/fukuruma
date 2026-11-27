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

static const double LN2_HI = 6.93147180369123816490e-01, LN2_LO = 1.90821492927058770002e-10;

double fk_dexp(double x) {
    if (x != x) return x;
    if (x > 709.78) return INFINITY;
    if (x < -745.2) return 0;
    const double P1 = 1.66666666666666019037e-01, P2 = -2.77777777770155933842e-03, P3 = 6.61375632143793436117e-05,
                 P4 = -1.65339022054652515390e-06, P5 = 4.13813679705723846039e-08;
    double k = floor(x * 1.44269504088896338700e+00 + 0.5);
    double hi = x - k * LN2_HI, lo = k * LN2_LO, r = hi - lo, t = r * r;
    double c = r - t * (P1 + t * (P2 + t * (P3 + t * (P4 + t * P5))));
    double y = 1.0 - ((lo - (r * c) / (2.0 - c)) - hi);
    return ldexp(y, (int)k); /* exact scaling by a power of two */
}

double fk_dlog(double x) {
    if (x != x || x < 0) return NAN;
    if (x == 0) return -INFINITY;
    if (isinf(x)) return x;
    const double Lg1 = 6.666666666666735130e-01, Lg2 = 3.999999999940941908e-01, Lg3 = 2.857142874366239149e-01,
                 Lg4 = 2.222219843214978396e-01, Lg5 = 1.818357216161805012e-01, Lg6 = 1.531383769920937332e-01,
                 Lg7 = 1.479819860511658591e-01;
    int e;
    double m = frexp(x, &e); /* exact: x = m * 2^e, m in [0.5, 1) */
    if (m < 0.70710678118654752440) m *= 2, e--;
    double f = m - 1.0, k = e, s = f / (2.0 + f), z = s * s, w = z * z;
    double R = z * (Lg1 + w * (Lg3 + w * (Lg5 + w * Lg7))) + w * (Lg2 + w * (Lg4 + w * Lg6));
    double hfsq = 0.5 * f * f;
    return k * LN2_HI - ((hfsq - (s * (hfsq + R) + k * LN2_LO)) - f);
}

static double datan(double x) {
    static const double hi[4] = {4.63647609000806093515e-01, 7.85398163397448278999e-01, 9.82793723247329054082e-01,
                                 1.57079632679489655800e+00};
    static const double lo[4] = {2.26987774529616870924e-17, 3.06161699786838301793e-17, 1.39033110312309984516e-17,
                                 6.12323399573676603587e-17};
    static const double aT[11] = {3.33333333333329318027e-01,  -1.99999999998764832476e-01, 1.42857142725034663711e-01,
                                  -1.11111104054623557880e-01, 9.09088713343650656196e-02,  -7.69187620504482999495e-02,
                                  6.66107313738753120669e-02,  -5.83357013379057348645e-02, 4.97687799461593236017e-02,
                                  -3.65315727442169155270e-02, 1.62858201153657823623e-02};
    double sign = x < 0 ? -1.0 : 1.0, a = fabs(x);
    int id;
    if (a < 0.4375) id = -1;
    else if (a < 0.6875) id = 0, a = (2.0 * a - 1.0) / (2.0 + a);
    else if (a < 1.1875) id = 1, a = (a - 1.0) / (a + 1.0);
    else if (a < 2.4375) id = 2, a = (a - 1.5) / (1.0 + 1.5 * a);
    else id = 3, a = -1.0 / a;
    double z = a * a, w = z * z;
    double s1 = z * (aT[0] + w * (aT[2] + w * (aT[4] + w * (aT[6] + w * (aT[8] + w * aT[10])))));
    double s2 = w * (aT[1] + w * (aT[3] + w * (aT[5] + w * (aT[7] + w * aT[9]))));
    if (id < 0) return sign * (a - a * (s1 + s2));
    return sign * (hi[id] - ((a * (s1 + s2) - lo[id]) - a));
}

double fk_datan2(double y, double x) {
    if (x != x || y != y) return NAN;
    if (x == 0) return y > 0 ? FK_PI / 2 : y < 0 ? -FK_PI / 2 : 0;
    double a = datan(y / x);
    if (x > 0) return a;
    return y >= 0 ? a + FK_PI : a - FK_PI;
}

double fk_dpow(double x, double y) {
    if (x == 0) return y > 0 ? 0 : INFINITY;
    return fk_dexp(y * fk_dlog(x));
}
