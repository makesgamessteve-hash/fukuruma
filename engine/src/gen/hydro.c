/* Water courses (rivers-and-lakes spec), see hydro.h. */
#include "gen/hydro.h"

#include <math.h>
#include <string.h>

#include "gen/planet.h"

#define LAKE_DEPTH 0.4f /* metres of filled basin before it counts as a lake */
#define RIVER_FLOW 300  /* samples draining through a point before a river runs there */
#define FALL 1.2f       /* metres a river drops between two samples to run white (falls and rapids) */
#define BOWL 6.0        /* metres: the deepest lake basin pressed into the ground */

size_t fk_hydro_size(int n) {
    size_t count = (size_t)(n + 1) * (size_t)(n + 1);
    /* carve, water, flow, height, filled; to, queue, order; kind, closed */
    return count * (5 * sizeof(float) + 3 * sizeof(int32_t) + 2) + 64;
}

/* Smooth value noise in the plane (0..1), on a lattice of hashed corners: the lake basins' layout. */
static double lattice(uint32_t seed, int32_t x, int32_t z) {
    uint32_t v = seed ^ ((uint32_t)x * 0x8da6b343u) ^ ((uint32_t)z * 0xd8163841u);
    v = (v ^ (v >> 15)) * 0x2c1b3c6du;
    v = (v ^ (v >> 12)) * 0x297a2d39u;
    return (double)((v ^ (v >> 15)) & 0xffffff) / 16777215.0;
}

static double value_noise(uint32_t seed, double x, double z) {
    double fx = floor(x), fz = floor(z), tx = x - fx, tz = z - fz;
    int32_t ix = (int32_t)fx, iz = (int32_t)fz;
    tx = tx * tx * (3 - 2 * tx), tz = tz * tz * (3 - 2 * tz);
    double a = lattice(seed, ix, iz), b = lattice(seed, ix + 1, iz), c = lattice(seed, ix, iz + 1), d = lattice(seed, ix + 1, iz + 1);
    return (a + (b - a) * tx) * (1 - tz) + (c + (d - c) * tx) * tz;
}

static void direction(const fk_hydro *h, double radius, double x, double z, double d[3]) {
    double l = 0;
    for (int k = 0; k < 3; k++) d[k] = h->up[k] * radius + h->east[k] * x + h->north[k] * z, l += d[k] * d[k];
    l = sqrt(l);
    for (int k = 0; k < 3; k++) d[k] /= l;
}

/* The flood's queue: a binary heap of samples by filled height, ties by index (deterministic). */
typedef struct {
    int32_t *items;
    int count;
    const float *key;
} heap;

static int before(const heap *q, int32_t a, int32_t b) { return q->key[a] < q->key[b] || (q->key[a] == q->key[b] && a < b); }

static void push(heap *q, int32_t v) {
    int i = q->count++;
    q->items[i] = v;
    while (i > 0 && before(q, q->items[i], q->items[(i - 1) / 2])) {
        int32_t t = q->items[i];
        q->items[i] = q->items[(i - 1) / 2], q->items[(i - 1) / 2] = t, i = (i - 1) / 2;
    }
}

static int32_t pop(heap *q) {
    int32_t top = q->items[0];
    q->items[0] = q->items[--q->count];
    for (int i = 0;;) {
        int l = 2 * i + 1, r = l + 1, m = i;
        if (l < q->count && before(q, q->items[l], q->items[m])) m = l;
        if (r < q->count && before(q, q->items[r], q->items[m])) m = r;
        if (m == i) break;
        int32_t t = q->items[i];
        q->items[i] = q->items[m], q->items[m] = t, i = m;
    }
    return top;
}

int fk_hydro_build(fk_hydro *h, void *memory, const fk_planet *p, const double up[3], const double east[3],
                   const double north[3], int n, double cell, double keep) {
    const int row = n + 1, count = row * row;
    memset(h, 0, sizeof *h);
    memcpy(h->up, up, sizeof h->up), memcpy(h->east, east, sizeof h->east), memcpy(h->north, north, sizeof h->north);
    h->cell = cell, h->n = n;
    memset(memory, 0, fk_hydro_size(n));
    float *f = memory, *ground = f + 3 * count, *filled = f + 4 * count;
    h->carve = f, h->water = f + count, h->flow = f + 2 * count;
    h->to = (int32_t *)(f + 5 * count);
    int32_t *queue = h->to + count, *order = queue + count;
    h->kind = (uint8_t *)(order + count);
    uint8_t *closed = h->kind + count;
    const double half = n * cell / 2;
    double here = fk_planet_height(p, up); /* the noise's seed: the world's own height at the range, to the millimetre */
    uint32_t seed = (uint32_t)(int64_t)floor(here * 1000) ^ (uint32_t)(int64_t)floor(p->radius);
    h->seed = seed;
    for (int j = 0; j < row; j++)
        for (int i = 0; i < row; i++) {
            double d[3];
            direction(h, p->radius, -half + i * cell, -half + j * cell, d);
            ground[j * row + i] = (float)fk_planet_height(p, d);
            /* lake basins: shallow bowls where a slow noise (the height graph, stretched and moved) rises high; the
               flood below fills them, and rivers run in and out of them */
            double x = -half + i * cell, z = -half + j * cell, b = 0;
            if (x * x + z * z > keep * keep) { /* basins some 300 m across, a few per square kilometre */
                b = 0.65 * value_noise(seed, x / 420, z / 420) + 0.35 * value_noise(seed + 1, x / 170, z / 170);
                b = b > 0.67 ? (b - 0.67) / 0.1 : 0;
                b = b > 1 ? BOWL : BOWL * b * b * (3 - 2 * b);
            }
            h->carve[j * row + i] = (float)b;
            ground[j * row + i] -= (float)b;
        }
    /* The flood, from the square's edges and the sea: the order samples leave the queue drains each to the one it was
       reached from, and a basin fills to the lowest point of its rim (plus a hair per step, so water always runs). */
    heap q = {queue, 0, filled};
    for (int c = 0; c < count; c++) {
        int i = c % row, j = c / row;
        h->to[c] = -1;
        if (i == 0 || j == 0 || i == n || j == n || (p->ocean && ground[c] < 0)) {
            filled[c] = ground[c], closed[c] = 1;
            push(&q, c);
        }
    }
    int popped = 0;
    static const int DI[8] = {1, -1, 0, 0, 1, 1, -1, -1}, DJ[8] = {0, 0, 1, -1, 1, -1, 1, -1};
    while (q.count) {
        int32_t c = pop(&q);
        order[popped++] = c;
        int i = c % row, j = c / row;
        for (int k = 0; k < 8; k++) {
            int a = i + DI[k], b = j + DJ[k];
            if (a < 0 || b < 0 || a > n || b > n || closed[b * row + a]) continue;
            int32_t nb = b * row + a;
            closed[nb] = 1;
            float least = filled[c] + 1e-4f * (k < 4 ? 1.0f : 1.41421356f);
            filled[nb] = ground[nb] > least ? ground[nb] : least;
            h->to[nb] = c;
            push(&q, nb);
        }
    }
    /* Flow: from the last sample reached (highest) back to the outlets, each passes what drains through it on. */
    for (int k = popped - 1; k >= 0; k--) {
        int32_t c = order[k];
        h->flow[c] += 1;
        if (h->to[c] >= 0) h->flow[h->to[c]] += h->flow[c];
    }
    int rivers = 0;
    for (int c = 0; c < count; c++) {
        int i = c % row, j = c / row;
        double x = -half + i * cell, z = -half + j * cell;
        if (p->ocean && ground[c] < 0) { /* the sea: its floor kept in water, for rivers that pour into it */
            h->water[c] = ground[c];
            continue;
        }
        if (filled[c] - ground[c] > LAKE_DEPTH) {
            h->kind[c] = FK_WATER_LAKE, h->water[c] = filled[c];
        } else if (h->flow[c] >= RIVER_FLOW && x * x + z * z > keep * keep && h->to[c] >= 0) {
            float depth = 0.6f + 0.04f * sqrtf(h->flow[c]);
            depth = depth > 4 ? 4 : depth;
            h->kind[c] = FK_WATER_RIVER, h->water[c] = ground[c] - depth * 0.3f;
            if (depth > h->carve[c]) h->carve[c] = depth;
            for (int k = 0; k < 8; k++) { /* banks: a gentler slope into the channel */
                int a = i + DI[k], b = j + DJ[k];
                if (a < 0 || b < 0 || a > n || b > n) continue;
                double bx = -half + a * cell, bz = -half + b * cell;
                if (bx * bx + bz * bz <= keep * keep) continue;
                float bank = depth * 0.4f;
                if (bank > h->carve[b * row + a]) h->carve[b * row + a] = bank;
            }
            rivers++;
        }
    }
    return rivers;
}

double fk_hydro_carve(const fk_hydro *h, double radius, const double d[3]) {
    double cu = d[0] * h->up[0] + d[1] * h->up[1] + d[2] * h->up[2];
    if (cu <= 0) return 0;
    double half = h->n * h->cell / 2;
    double gx = (radius * (d[0] * h->east[0] + d[1] * h->east[1] + d[2] * h->east[2]) / cu + half) / h->cell;
    double gz = (radius * (d[0] * h->north[0] + d[1] * h->north[1] + d[2] * h->north[2]) / cu + half) / h->cell;
    if (gx < 0 || gz < 0 || gx >= h->n || gz >= h->n) return 0;
    int i = (int)gx, j = (int)gz, row = h->n + 1;
    double fx = gx - i, fz = gz - j;
    const float *c = &h->carve[j * row + i];
    return (c[0] * (1 - fx) + c[1] * fx) * (1 - fz) + (c[row] * (1 - fx) + c[row + 1] * fx) * fz;
}

/* A vertex of the water surface at grid position (x, z) and surface height w. */
static void vertex(const fk_hydro *h, const fk_planet *p, double base, double x, double z, double w, const float rgb[3],
                   fk_vertex *v) {
    double d[3];
    direction(h, p->radius, x, z, d);
    double cosine = d[0] * h->up[0] + d[1] * h->up[1] + d[2] * h->up[2];
    memset(v, 0, sizeof *v);
    v->position[0] = (float)x, v->position[1] = (float)((p->radius + w) * cosine - base), v->position[2] = (float)z;
    v->normal[1] = 1;
    memcpy(v->color, rgb, sizeof v->color);
}

static int quad(fk_vertex *out, uint32_t *idx, int nv, const fk_vertex q[4]) {
    if (out) {
        static const int ORDER[6] = {0, 2, 1, 1, 2, 3}; /* counter-clockwise from above */
        for (int k = 0; k < 6; k++) out[nv + k] = q[ORDER[k]], idx[nv + k] = (uint32_t)(nv + k);
    }
    return nv + 6;
}

int fk_hydro_mesh(const fk_hydro *h, const fk_planet *p, fk_vertex *vertices, uint32_t *indices) {
    static const float WATER[3] = {0.1f, 0.2f, 0.22f}, FOAM[3] = {0.85f, 0.9f, 0.92f};
    const int row = h->n + 1;
    const double half = h->n * h->cell / 2, base = p->radius + fk_planet_height(p, h->up);
    int nv = 0;
    fk_vertex q[4];
    for (int c = 0; c < row * row; c++) { /* river ribbons, from each river sample to where it drains */
        if (h->kind[c] != FK_WATER_RIVER) continue;
        int t = h->to[c];
        /* river samples are moved a little off the grid (the same way on every path through them): courses wander */
        double x0 = -half + (c % row) * h->cell, z0 = -half + (c / row) * h->cell;
        double x1 = -half + (t % row) * h->cell, z1 = -half + (t / row) * h->cell;
        x0 += (lattice(h->seed + 7, c % row, c / row) - 0.5) * 0.6 * h->cell;
        z0 += (lattice(h->seed + 8, c % row, c / row) - 0.5) * 0.6 * h->cell;
        if (h->kind[t] == FK_WATER_RIVER) {
            x1 += (lattice(h->seed + 7, t % row, t / row) - 0.5) * 0.6 * h->cell;
            z1 += (lattice(h->seed + 8, t % row, t / row) - 0.5) * 0.6 * h->cell;
        }
        double w0 = h->water[c], w1 = h->kind[t] ? h->water[t] : w0 - 0.2;
        if (!h->kind[t] && p->ocean && h->water[t] < 0) w1 = 0; /* into the sea (its samples keep their ground below) */
        double dx = x1 - x0, dz = z1 - z0, l = sqrt(dx * dx + dz * dz), width = 3 + 0.12 * sqrt(h->flow[c]);
        width = width > 12 ? 12 : width;
        double sx = -dz / l * width / 2, sz = dx / l * width / 2;
        const float *rgb = w0 - w1 > FALL ? FOAM : WATER;
        if (vertices) {
            vertex(h, p, base, x0 - sx, z0 - sz, w0, rgb, &q[0]);
            vertex(h, p, base, x0 + sx, z0 + sz, w0, rgb, &q[1]);
            vertex(h, p, base, x1 - sx, z1 - sz, w1, rgb, &q[2]);
            vertex(h, p, base, x1 + sx, z1 + sz, w1, rgb, &q[3]);
        }
        nv = quad(vertices, indices, nv, q);
    }
    for (int j = 0; j < h->n; j++) /* lakes: flat at their level over every cell that touches one */
        for (int i = 0; i < h->n; i++) {
            int corner[4] = {j * row + i, j * row + i + 1, (j + 1) * row + i, (j + 1) * row + i + 1};
            double level = -1e30;
            for (int k = 0; k < 4; k++)
                if (h->kind[corner[k]] == FK_WATER_LAKE && h->water[corner[k]] > level) level = h->water[corner[k]];
            if (level < -1e29) continue;
            if (vertices)
                for (int k = 0; k < 4; k++)
                    vertex(h, p, base, -half + (i + (k & 1)) * h->cell, -half + (j + (k >> 1)) * h->cell, level, WATER, &q[k]);
            nv = quad(vertices, indices, nv, q);
        }
    return nv;
}
