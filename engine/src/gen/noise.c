#include "gen/noise.h"

#include <math.h>

#include "core/dmath.h"
#include "core/rng.h"

static uint64_t hash3(uint64_t seed, int64_t x, int64_t y, int64_t z) {
    uint64_t h = seed ^ 0x9e3779b97f4a7c15ull;
    h = fk_mix64(h ^ (uint64_t)x * 0xbf58476d1ce4e5b9ull);
    h = fk_mix64(h ^ (uint64_t)y * 0x94d049bb133111ebull);
    return fk_mix64(h ^ (uint64_t)z * 0x2545f4914f6cdd1dull);
}

static const double GRAD[12][3] = {{1, 1, 0}, {-1, 1, 0}, {1, -1, 0}, {-1, -1, 0}, {1, 0, 1}, {-1, 0, 1},
                                   {1, 0, -1}, {-1, 0, -1}, {0, 1, 1}, {0, -1, 1}, {0, 1, -1}, {0, -1, -1}};

static double fade(double t) { return t * t * t * (t * (t * 6 - 15) + 10); }
static double lerp(double a, double b, double t) { return a + (b - a) * t; }

double fk_perlin(uint64_t seed, double x, double y, double z) {
    double fx = floor(x), fy = floor(y), fz = floor(z);
    int64_t ix = (int64_t)fx, iy = (int64_t)fy, iz = (int64_t)fz;
    double dx = x - fx, dy = y - fy, dz = z - fz, c[8];
    for (int k = 0; k < 8; k++) {
        int i = k & 1, j = (k >> 1) & 1, l = k >> 2;
        const double *g = GRAD[hash3(seed, ix + i, iy + j, iz + l) % 12];
        c[k] = g[0] * (dx - i) + g[1] * (dy - j) + g[2] * (dz - l);
    }
    double u = fade(dx), v = fade(dy), w = fade(dz);
    return lerp(lerp(lerp(c[0], c[1], u), lerp(c[2], c[3], u), v), lerp(lerp(c[4], c[5], u), lerp(c[6], c[7], u), v), w);
}

static double unit(uint64_t h) { return (double)(h >> 11) * (1.0 / 9007199254740992.0); }

/* Worley: the distances to the nearest and second-nearest feature points (one per cell). */
static void cells(uint64_t seed, double x, double y, double z, double *f1, double *f2, uint64_t *nearest) {
    double fx = floor(x), fy = floor(y), fz = floor(z);
    int64_t ix = (int64_t)fx, iy = (int64_t)fy, iz = (int64_t)fz;
    *f1 = *f2 = 1e9;
    *nearest = 0;
    for (int k = -1; k <= 1; k++)
        for (int j = -1; j <= 1; j++)
            for (int i = -1; i <= 1; i++) {
                uint64_t h = hash3(seed, ix + i, iy + j, iz + k);
                double px = fx + i + unit(h), py = fy + j + unit(fk_mix64(h + 1)), pz = fz + k + unit(fk_mix64(h + 2));
                double d = sqrt((px - x) * (px - x) + (py - y) * (py - y) + (pz - z) * (pz - z));
                if (d < *f1) *f2 = *f1, *f1 = d, *nearest = h;
                else if (d < *f2) *f2 = d;
            }
}

/* Bowls with raised rims, one possible crater per cell. */
static double craters(uint64_t seed, double density, double x, double y, double z) {
    double fx = floor(x), fy = floor(y), fz = floor(z), sum = 0;
    int64_t ix = (int64_t)fx, iy = (int64_t)fy, iz = (int64_t)fz;
    for (int k = -1; k <= 1; k++)
        for (int j = -1; j <= 1; j++)
            for (int i = -1; i <= 1; i++) {
                uint64_t h = hash3(seed, ix + i, iy + j, iz + k);
                if (unit(fk_mix64(h + 3)) >= density) continue;
                double r = 0.1 + 0.35 * unit(fk_mix64(h + 4));
                double px = fx + i + unit(h), py = fy + j + unit(fk_mix64(h + 1)), pz = fz + k + unit(fk_mix64(h + 2));
                double d = sqrt((px - x) * (px - x) + (py - y) * (py - y) + (pz - z) * (pz - z)) / r;
                if (d < 1) sum += (d * d - 1) * r * 2;                    /* the bowl */
                else if (d < 1.4) sum += 0.3 * r * 2 * (1 - (d - 1) / 0.4) * (1 - (d - 1) / 0.4); /* the rim */
            }
    return sum;
}

static double fractal(const fk_noise_node *n, double x, double y, double z) {
    double f = n->p[0], amp = 1, total = 0, norm = 0;
    for (int o = 0; o < n->octaves; o++) {
        double v = fk_perlin(n->seed + (uint64_t)o * 0x632be59bd9b4e019ull, x * f, y * f, z * f);
        if (n->op == FK_N_RIDGED) v = (1 - fabs(v)) * (1 - fabs(v));
        else if (n->op == FK_N_BILLOW) v = 2 * fabs(v) - 1;
        total += v * amp;
        norm += amp;
        f *= n->p[1];
        amp *= n->p[2];
    }
    return total / norm;
}

static double eval(const fk_noise *g, int i, double x, double y, double z) {
    const fk_noise_node *n = &g->nodes[i];
    double a = 0, b = 0, f1, f2;
    uint64_t nearest;
    switch (n->op) {
    case FK_N_CONST: return n->p[0];
    case FK_N_PERLIN: return fk_perlin(n->seed, x * n->p[0], y * n->p[0], z * n->p[0]);
    case FK_N_FBM:
    case FK_N_RIDGED:
    case FK_N_BILLOW: return fractal(n, x, y, z);
    case FK_N_CELLS:
        cells(n->seed, x * n->p[0], y * n->p[0], z * n->p[0], &f1, &f2, &nearest);
        return n->p[1] >= 0.5 ? f2 - f1 : f1;
    case FK_N_CRATERS: return craters(n->seed, n->p[1], x * n->p[0], y * n->p[0], z * n->p[0]);
    case FK_N_WARP: {
        double s = n->p[0];
        double wx = eval(g, n->in[1], x + 5.2, y + 1.3, z + 7.7), wy = eval(g, n->in[1], x + 1.7, y + 9.2, z + 3.1),
               wz = eval(g, n->in[1], x + 8.3, y + 2.8, z + 4.6);
        return eval(g, n->in[0], x + wx * s, y + wy * s, z + wz * s);
    }
    case FK_N_LATITUDE: return y;
    default: break;
    }
    a = eval(g, n->in[0], x, y, z);
    if (n->in[1] >= 0) b = eval(g, n->in[1], x, y, z);
    switch (n->op) {
    case FK_N_ADD: return a + b;
    case FK_N_SUB: return a - b;
    case FK_N_MUL: return a * b;
    case FK_N_MIN: return a < b ? a : b;
    case FK_N_MAX: return a > b ? a : b;
    case FK_N_BLEND: {
        double t = eval(g, n->in[2], x, y, z);
        t = t < 0 ? 0 : t > 1 ? 1 : t;
        return a + (b - a) * t;
    }
    case FK_N_SCALE: return a * n->p[0] + n->p[1];
    case FK_N_CLAMP: return a < n->p[0] ? n->p[0] : a > n->p[1] ? n->p[1] : a;
    case FK_N_ABS: return fabs(a);
    case FK_N_TERRACE: { /* flat steps; with p[1] > 0 the risers are eased (flat at both ends) */
        double steps = a * n->p[0], k = floor(steps);
        return (k + n->p[1] * fade(steps - k)) / n->p[0];
    }
    case FK_N_SMOOTH: {
        double t = (a - n->p[0]) / (n->p[1] - n->p[0]);
        t = t < 0 ? 0 : t > 1 ? 1 : t;
        return t * t * (3 - 2 * t);
    }
    default: /* FK_N_POWER */
        return a == 0 ? 0 : (a < 0 ? -1 : 1) * fk_dpow(fabs(a), n->p[0]);
    }
}

double fk_noise_eval(const fk_noise *g, double x, double y, double z) { return eval(g, g->count - 1, x, y, z); }

const char *fk_noise_check(const fk_noise *g) {
    if (g->count < 1 || g->count > FK_NOISE_MAX_NODES) return "a graph needs 1 to 256 nodes";
    static const int inputs[FK_N_COUNT] = {0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 3, 1, 1, 1, 1, 1, 1, 0};
    for (int i = 0; i < g->count; i++) {
        const fk_noise_node *n = &g->nodes[i];
        if (n->op < 0 || n->op >= FK_N_COUNT) return "unknown node";
        for (int k = 0; k < inputs[n->op]; k++)
            if (n->in[k] < 0 || n->in[k] >= i) return "a node's input must be an earlier node";
        if ((n->op == FK_N_FBM || n->op == FK_N_RIDGED || n->op == FK_N_BILLOW) && (n->octaves < 1 || n->octaves > 16))
            return "octaves must be from 1 to 16";
        if (n->op == FK_N_TERRACE && !(n->p[0] >= 1)) return "terrace steps must be at least 1";
        if (n->op == FK_N_SMOOTH && !(n->p[1] != n->p[0])) return "smooth needs two different edges";
    }
    return NULL;
}
