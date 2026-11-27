/* Deterministic double-precision math: only +, -, *, / and floor, so the bits are the same on every platform
   (with -ffp-contract=off). The C library's sin and cos may differ in the last bit between platforms. */
#pragma once

#define FK_PI 3.14159265358979323846
#define FK_TAU 6.28318530717958647692

/* Sine and cosine within about 1 ulp of the exact values for |x| up to 1e6; larger arguments are first wrapped
   into one turn (less exact, still deterministic). */
double fk_dsin(double x);
double fk_dcos(double x);
void fk_dsincos(double x, double *s, double *c);
/* x wrapped into [-pi, pi). */
double fk_dwrap(double x);
/* e^x, the natural logarithm (NaN below 0, -inf at 0), atan2 and x^y (x > 0; 0 for x == 0 and y > 0), within a few
   ulp of the exact values. */
double fk_dexp(double x);
double fk_dlog(double x);
double fk_datan2(double y, double x);
double fk_dpow(double x, double y);
