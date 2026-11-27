/* Dug ground (voxel-terrain spec): the range's world as a solid, s(p) = max(ground distance, the digs' holes), where s
   is negative inside the ground. The physics world collides with the same field (physics/terrain.c); this meshes
   the walls the digs leave, by marching tetrahedra over a lattice of `cell` metres (no large tables; each cube in six
   tetrahedra around its diagonal). Triangles on the untouched ground are left out: the planet's chunks draw that.
   Coordinates: the range's local frame (y up, metres). Deterministic, read-only inputs: runs in jobs. */
#include "gen/dig.h"

#include <math.h>
#include <string.h>

double fk_dig_ground(const fk_dig_field *f, double x, double z) {
    double d[3], l = 0;
    for (int k = 0; k < 3; k++) d[k] = f->up[k] * f->planet->radius + f->east[k] * x + f->north[k] * z, l += d[k] * d[k];
    l = sqrt(l);
    for (int k = 0; k < 3; k++) d[k] /= l;
    double r = f->planet->radius + fk_planet_height(f->planet, d);
    return r * (d[0] * f->up[0] + d[1] * f->up[1] + d[2] * f->up[2]) - f->base;
}

static double hole(const fk_dig_field *f, double x, double y, double z) {
    double best = -1e30;
    for (int i = 0; i < f->ndigs; i++) {
        const float *g = &f->digs[4 * i];
        double dx = x - g[0], dy = y - g[1], dz = z - g[2], h = g[3] - sqrt(dx * dx + dy * dy + dz * dz);
        if (h > best) best = h;
    }
    return best;
}

double fk_dig_solid(const fk_dig_field *f, double x, double y, double z) {
    double s = y - fk_dig_ground(f, x, z), h = hole(f, x, y, z);
    return h > s ? h : s;
}

static void gradient(const fk_dig_field *f, const double p[3], double n[3]) {
    const double E = 0.02;
    for (int k = 0; k < 3; k++) {
        double a[3] = {p[0], p[1], p[2]}, b[3] = {p[0], p[1], p[2]};
        a[k] += E, b[k] -= E;
        n[k] = fk_dig_solid(f, a[0], a[1], a[2]) - fk_dig_solid(f, b[0], b[1], b[2]);
    }
    double l = sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
    if (l > 0) for (int k = 0; k < 3; k++) n[k] /= l;
    else n[0] = 0, n[1] = 1, n[2] = 0;
}

typedef struct {
    const fk_dig_field *f;
    fk_vertex *v;
    uint32_t *idx;
    int nv, ni, max_v, max_i;
    float soil[3], rock[3];
} out;

static void emit(out *o, const double a[3], const double b[3], const double c[3]) {
    double m[3], g[3];
    for (int k = 0; k < 3; k++) m[k] = (a[k] + b[k] + c[k]) / 3;
    double ground = m[1] - fk_dig_ground(o->f, m[0], m[2]);
    if (hole(o->f, m[0], m[1], m[2]) < ground - 1e-3) return; /* the untouched ground: the planet's chunks draw it */
    if (o->nv + 3 > o->max_v || o->ni + 3 > o->max_i) return;
    gradient(o->f, m, g);
    double e1[3] = {b[0] - a[0], b[1] - a[1], b[2] - a[2]}, e2[3] = {c[0] - a[0], c[1] - a[1], c[2] - a[2]};
    double cr[3] = {e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]};
    const double *p[3] = {a, b, c};
    if (cr[0] * g[0] + cr[1] * g[1] + cr[2] * g[2] < 0) p[1] = c, p[2] = b; /* face the open side */
    for (int t = 0; t < 3; t++) {
        fk_vertex *x = &o->v[o->nv];
        memset(x, 0, sizeof *x);
        double n[3];
        gradient(o->f, p[t], n);
        double depth = fk_dig_ground(o->f, p[t][0], p[t][2]) - p[t][1]; /* soil near the top, rock deeper down */
        double k = depth / 2.5, sky = exp(-(depth > 0 ? depth : 0) / 3.0); /* less of the sky's light the deeper */
        k = k < 0 ? 0 : k > 1 ? 1 : k;
        sky = 0.4 + 0.6 * sky;
        for (int q = 0; q < 3; q++) {
            x->position[q] = (float)p[t][q];
            x->normal[q] = (float)n[q];
            x->color[q] = (float)((o->soil[q] + (o->rock[q] - o->soil[q]) * k) * sky);
        }
        o->idx[o->ni++] = (uint32_t)o->nv++;
    }
}

static void edge(const double a[3], double sa, const double b[3], double sb, double at[3]) {
    double t = sa / (sa - sb);
    for (int k = 0; k < 3; k++) at[k] = a[k] + (b[k] - a[k]) * t;
}

static void tetra(out *o, const double p[4][3], const double s[4]) {
    int in[4], out_[4], ni = 0, no = 0;
    for (int i = 0; i < 4; i++) {
        if (s[i] < 0) in[ni++] = i;
        else out_[no++] = i;
    }
    if (ni == 0 || ni == 4) return;
    double q[4][3];
    if (ni == 1 || ni == 3) { /* one corner apart: a triangle */
        int lone = ni == 1 ? in[0] : out_[0];
        const int *others = ni == 1 ? out_ : in;
        for (int k = 0; k < 3; k++) edge(p[lone], s[lone], p[others[k]], s[others[k]], q[k]);
        emit(o, q[0], q[1], q[2]);
        return;
    }
    /* two and two: a quad */
    edge(p[in[0]], s[in[0]], p[out_[0]], s[out_[0]], q[0]);
    edge(p[in[0]], s[in[0]], p[out_[1]], s[out_[1]], q[1]);
    edge(p[in[1]], s[in[1]], p[out_[1]], s[out_[1]], q[2]);
    edge(p[in[1]], s[in[1]], p[out_[0]], s[out_[0]], q[3]);
    emit(o, q[0], q[1], q[2]);
    emit(o, q[0], q[2], q[3]);
}

int fk_dig_mesh(const fk_dig_field *f, const double lo[3], double cell, int n, const float soil[3], const float rock[3],
                fk_vertex *vertices, int max_vertices, uint32_t *indices, int max_indices) {
    static const int TETS[6][4] = {{0, 5, 1, 6}, {0, 1, 2, 6}, {0, 2, 3, 6}, {0, 3, 7, 6}, {0, 7, 4, 6}, {0, 4, 5, 6}};
    static const int CORNER[8][3] = {{0, 0, 0}, {1, 0, 0}, {1, 0, 1}, {0, 0, 1}, {0, 1, 0}, {1, 1, 0}, {1, 1, 1}, {0, 1, 1}};
    out o = {f, vertices, indices, 0, 0, max_vertices, max_indices, {0}, {0}};
    memcpy(o.soil, soil, sizeof o.soil);
    memcpy(o.rock, rock, sizeof o.rock);
    if (n > FK_DIG_MAX_N) n = FK_DIG_MAX_N;
    double ground[(FK_DIG_MAX_N + 1) * (FK_DIG_MAX_N + 1)]; /* the ground under each column of the lattice */
    for (int k = 0; k <= n; k++)
        for (int i = 0; i <= n; i++) ground[k * (n + 1) + i] = fk_dig_ground(f, lo[0] + i * cell, lo[2] + k * cell);
    for (int k = 0; k < n; k++)
        for (int j = 0; j < n; j++)
            for (int i = 0; i < n; i++) {
                double p[8][3], s[8];
                for (int c = 0; c < 8; c++) {
                    int ci = i + CORNER[c][0], ck = k + CORNER[c][2];
                    p[c][0] = lo[0] + ci * cell, p[c][1] = lo[1] + (j + CORNER[c][1]) * cell, p[c][2] = lo[2] + ck * cell;
                    double g = p[c][1] - ground[ck * (n + 1) + ci], h = hole(f, p[c][0], p[c][1], p[c][2]);
                    s[c] = h > g ? h : g;
                }
                for (int t = 0; t < 6; t++) {
                    double tp[4][3], ts[4];
                    for (int q = 0; q < 4; q++) memcpy(tp[q], p[TETS[t][q]], sizeof tp[q]), ts[q] = s[TETS[t][q]];
                    tetra(&o, (const double(*)[3])tp, ts);
                }
            }
    return o.ni;
}
