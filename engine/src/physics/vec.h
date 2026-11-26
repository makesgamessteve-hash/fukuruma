/* Small float vector helpers for physics/ (internal). Arithmetic and sqrtf only. */
#pragma once
#include <math.h>

static inline void v3_set(float o[3], float x, float y, float z) { o[0] = x, o[1] = y, o[2] = z; }
static inline void v3_copy(float o[3], const float a[3]) { o[0] = a[0], o[1] = a[1], o[2] = a[2]; }
static inline void v3_add(float o[3], const float a[3], const float b[3]) { o[0] = a[0] + b[0], o[1] = a[1] + b[1], o[2] = a[2] + b[2]; }
static inline void v3_sub(float o[3], const float a[3], const float b[3]) { o[0] = a[0] - b[0], o[1] = a[1] - b[1], o[2] = a[2] - b[2]; }
static inline void v3_scale(float o[3], const float a[3], float s) { o[0] = a[0] * s, o[1] = a[1] * s, o[2] = a[2] * s; }
static inline void v3_mad(float o[3], const float a[3], const float b[3], float s) { /* o = a + b * s */
    o[0] = a[0] + b[0] * s, o[1] = a[1] + b[1] * s, o[2] = a[2] + b[2] * s;
}
static inline float v3_dot(const float a[3], const float b[3]) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
static inline void v3_cross(float o[3], const float a[3], const float b[3]) {
    float x = a[1] * b[2] - a[2] * b[1], y = a[2] * b[0] - a[0] * b[2], z = a[0] * b[1] - a[1] * b[0];
    o[0] = x, o[1] = y, o[2] = z;
}
static inline float v3_len(const float a[3]) { return sqrtf(v3_dot(a, a)); }
static inline float v3_norm(float o[3], const float a[3]) { /* returns the length; o = 0 for a zero vector */
    float l = v3_len(a);
    if (l > 1e-20f) v3_scale(o, a, 1.0f / l);
    else v3_set(o, 0, 0, 0);
    return l;
}
static inline float clampf(float x, float lo, float hi) { return x < lo ? lo : x > hi ? hi : x; }
/* Column c of a rotation matrix (the body's axis c in the world). */
static inline const float *axis(const float r[9], int c) { return &r[c * 3]; }
/* World vector into the local frame of r and back. */
static inline void to_local(float o[3], const float r[9], const float v[3]) {
    float x = v3_dot(axis(r, 0), v), y = v3_dot(axis(r, 1), v), z = v3_dot(axis(r, 2), v);
    o[0] = x, o[1] = y, o[2] = z;
}
static inline void to_world(float o[3], const float r[9], const float v[3]) {
    float x = r[0] * v[0] + r[3] * v[1] + r[6] * v[2], y = r[1] * v[0] + r[4] * v[1] + r[7] * v[2],
          z = r[2] * v[0] + r[5] * v[1] + r[8] * v[2];
    o[0] = x, o[1] = y, o[2] = z;
}
