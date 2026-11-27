/* Terrain (terrain-streaming spec): a heightfield in the world's frame (y up) that bodies and characters rest on.
   Each cell is split into two triangles along the same diagonal; a point's ground is the plane of the triangle
   under it. Digs (voxel-terrain spec) open spheres in it: near one, the ground is a solid with a distance field.
   Only arithmetic and sqrt, so it is deterministic like the rest of the world. */
#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "physics/physics.h"
#include "physics/vec.h"

void fk_terrain_set(fk_terrain *t, float x0, float z0, float cell, int n, const float *heights) {
    free(t->h);
    float *digs = t->digs; /* the digs belong to the world, not to the tile */
    int ndigs = t->ndigs;
    memset(t, 0, sizeof *t);
    t->digs = digs, t->ndigs = ndigs;
    if (!heights || n <= 0) return;
    size_t count = (size_t)(n + 1) * (size_t)(n + 1);
    t->h = malloc(count * sizeof *t->h);
    if (!t->h) abort();
    memcpy(t->h, heights, count * sizeof *t->h);
    t->x0 = x0, t->z0 = z0, t->cell = cell, t->n = n;
}

bool fk_terrain_height(const fk_terrain *t, float x, float z, float *height, float normal[3]) {
    if (!t->h) return false;
    float gx = (x - t->x0) / t->cell, gz = (z - t->z0) / t->cell;
    if (!(gx >= 0 && gz >= 0 && gx <= (float)t->n && gz <= (float)t->n)) return false;
    int i = (int)gx, j = (int)gz;
    if (i == t->n) i--;
    if (j == t->n) j--;
    float fx = gx - (float)i, fz = gz - (float)j;
    int row = t->n + 1;
    float h00 = t->h[j * row + i], h10 = t->h[j * row + i + 1], h01 = t->h[(j + 1) * row + i], h11 = t->h[(j + 1) * row + i + 1];
    float dx, dz;
    if (fx + fz <= 1) {
        dx = h10 - h00, dz = h01 - h00;
        *height = h00 + dx * fx + dz * fz;
    } else {
        dx = h11 - h01, dz = h11 - h10;
        *height = h11 - dx * (1 - fx) - dz * (1 - fz);
    }
    if (normal) {
        v3_set(normal, -dx / t->cell, 1, -dz / t->cell);
        v3_norm(normal, normal);
    }
    return true;
}

/* A sphere at c of radius r against the ground: the plane of the triangle under its centre. */
/* Inside the dug space, the distance to the solid around it is the distance to the nearest point of its boundary:
   a dig's wall where no other dig covers it and it lies below the ground, the crease where two digs' walls meet, or a
   dig's rim, where its wall meets the ground (taken as level at the point's own ground height h). Taking the furthest
   containing dig's wall instead underestimates the distance where digs overlap: a ridge at the seam the suit stops at. */
#define FK_NEAR_DIGS 32

static float ground_at(const fk_terrain *t, float x, float z, float fallback) {
    float h, n[3];
    return fk_terrain_height(t, x, z, &h, n) ? h : fallback;
}

static bool covered(const fk_terrain *t, const float q[3], const int *near, int count, int skip_a, int skip_b) {
    for (int k = 0; k < count; k++) {
        if (near[k] == skip_a || near[k] == skip_b) continue;
        const float *d = &t->digs[4 * near[k]];
        float dx = q[0] - d[0], dy = q[1] - d[1], dz = q[2] - d[2], r = d[3] - 1e-3f;
        if (dx * dx + dy * dy + dz * dz < r * r) return true;
    }
    return false;
}

static void closer(const float p[3], const float q[3], float *best) {
    float dx = q[0] - p[0], dy = q[1] - p[1], dz = q[2] - p[2], l = sqrtf(dx * dx + dy * dy + dz * dz);
    if (l < *best) *best = l;
}

static float open_distance(const fk_terrain *t, const float p[3], float h, float least) {
    int near[FK_NEAR_DIGS], count = 0;
    for (int i = 0; i < t->ndigs && count < FK_NEAR_DIGS; i++) { /* the digs a boundary point within reach could be in */
        const float *d = &t->digs[4 * i];
        float dx = p[0] - d[0], dy = p[1] - d[1], dz = p[2] - d[2], reach = 3 * d[3];
        if (dx * dx + dy * dy + dz * dz < reach * reach) near[count++] = i;
    }
    float best = 1e9f;
    for (int a = 0; a < count; a++) {
        const float *d = &t->digs[4 * near[a]];
        float v[3] = {p[0] - d[0], p[1] - d[1], p[2] - d[2]}, l = sqrtf(v3_dot(v, v)), q[3];
        if (l < 1e-6f) v3_set(v, 0, -1, 0), l = 1;
        for (int k = 0; k < 3; k++) q[k] = d[k] + v[k] * d[3] / l; /* the wall straight out from the centre */
        if (q[1] <= ground_at(t, q[0], q[2], h) && !covered(t, q, near, count, near[a], -1)) closer(p, q, &best);
        float k = h - d[1]; /* the rim */
        if (k * k < d[3] * d[3]) {
            float rho = sqrtf(d[3] * d[3] - k * k), hx = v[0], hz = v[2], hl = sqrtf(hx * hx + hz * hz);
            if (hl < 1e-6f) hx = 1, hz = 0, hl = 1;
            float r[3] = {d[0] + hx / hl * rho, h, d[2] + hz / hl * rho};
            if (!covered(t, r, near, count, near[a], -1)) closer(p, r, &best);
        }
        for (int b = a + 1; b < count; b++) { /* the crease with another dig */
            const float *e = &t->digs[4 * near[b]];
            float u[3] = {e[0] - d[0], e[1] - d[1], e[2] - d[2]}, dist = sqrtf(v3_dot(u, u));
            if (dist >= d[3] + e[3] || dist <= fabsf(d[3] - e[3])) continue;
            for (int c = 0; c < 3; c++) u[c] /= dist;
            float along = (dist * dist + d[3] * d[3] - e[3] * e[3]) / (2 * dist), rho = sqrtf(d[3] * d[3] - along * along);
            float m[3] = {d[0] + u[0] * along, d[1] + u[1] * along, d[2] + u[2] * along};
            float w[3] = {p[0] - m[0], p[1] - m[1], p[2] - m[2]}, wu = v3_dot(w, u);
            for (int c = 0; c < 3; c++) w[c] -= u[c] * wu;
            float wl = sqrtf(v3_dot(w, w));
            if (wl < 1e-6f) { /* on the axis: any point of the circle; one across the axis */
                float side[3] = {u[2], 0, -u[0]};
                if (v3_dot(side, side) < 1e-6f) v3_set(side, 1, 0, 0);
                v3_norm(w, side), wl = 1;
            }
            float cq[3] = {m[0] + w[0] / wl * rho, m[1] + w[1] / wl * rho, m[2] + w[2] / wl * rho};
            if (cq[1] <= ground_at(t, cq[0], cq[2], h) && !covered(t, cq, near, count, near[a], near[b])) closer(p, cq, &best);
        }
    }
    return best < least ? least : best; /* never nearer than the furthest containing dig's wall (a corner missed above) */
}

/* The ground with its digs as a solid, about the distance to its surface (positive in the open). Above the ground the
   surface below is its own, unless a dig's opening lies under the point; inside a dig, the boundary of the dug space.
   (The simple max of the two fields marks the same surface, but underestimates the distance over an opening.) */
float fk_terrain_solid(const fk_terrain *t, const float p[3]) {
    float h, n[3];
    if (!fk_terrain_height(t, p[0], p[2], &h, n)) return 1e9f;
    float ground = (p[1] - h) * n[1], hole = -1e9f;
    bool inside = false;
    for (int i = 0; i < t->ndigs; i++) {
        const float *d = &t->digs[4 * i];
        float dx = p[0] - d[0], dy = p[1] - d[1], dz = p[2] - d[2], fy = h - d[1];
        float in = d[3] - sqrtf(dx * dx + dy * dy + dz * dz);
        if (in > hole) hole = in;
        if (in > 0 || (ground > 0 && dx * dx + fy * fy + dz * dz < d[3] * d[3])) inside = true; /* or over its opening */
    }
    if (inside) return open_distance(t, p, h, hole > 0 ? hole : 0);
    return ground > hole ? ground : hole;
}

static bool near_dig(const fk_terrain *t, const float c[3], float r) {
    for (int i = 0; i < t->ndigs; i++) {
        const float *d = &t->digs[4 * i];
        float dx = c[0] - d[0], dy = c[1] - d[1], dz = c[2] - d[2], reach = d[3] + r + 0.5f;
        if (dx * dx + dy * dy + dz * dz < reach * reach) return true;
    }
    return false;
}

/* A sphere against the dug ground: the solid's distance and its gradient (central differences) for the normal. */
static int sphere_dug(const fk_terrain *t, const float c[3], float r, fk_touch *out, uint32_t key) {
    float s = fk_terrain_solid(t, c);
    if (s >= r) return 0;
    const float E = 0.02f;
    float n[3];
    for (int k = 0; k < 3; k++) {
        float a[3] = {c[0], c[1], c[2]}, b[3] = {c[0], c[1], c[2]};
        a[k] += E, b[k] -= E;
        n[k] = fk_terrain_solid(t, a) - fk_terrain_solid(t, b);
    }
    if (v3_norm(n, n) <= 0) v3_set(n, 0, 1, 0);
    out->depth = r - s;
    v3_copy(out->normal, n);
    v3_mad(out->point, c, n, -0.5f * (r + s));
    out->key = key;
    return 1;
}

static int sphere(const fk_terrain *t, const float c[3], float r, fk_touch *out, uint32_t key) {
    if (t->ndigs && near_dig(t, c, r)) return sphere_dug(t, c, r, out, key);
    float h, n[3];
    if (!fk_terrain_height(t, c[0], c[2], &h, n)) return 0;
    float d = (c[1] - h) * n[1]; /* the distance from the plane, along its normal */
    if (d >= r) return 0;
    out->depth = r - d;
    v3_copy(out->normal, n);
    v3_mad(out->point, c, n, -0.5f * (r + d));
    out->key = key;
    return 1;
}

int fk_terrain_collide(const fk_terrain *t, const fk_body *b, fk_touch out[4]) {
    int count = 0;
    if (b->shape.type == FK_SHAPE_SPHERE) return sphere(t, b->p, b->shape.radius, out, 0);
    if (b->shape.type == FK_SHAPE_CAPSULE) {
        for (int e = 0; e < 2; e++) {
            float c[3];
            v3_mad(c, b->p, axis(b->r, 1), e ? b->shape.half[1] : -b->shape.half[1]);
            count += sphere(t, c, b->shape.radius, &out[count], (uint32_t)e);
        }
        return count;
    }
    fk_touch all[8]; /* a box: its corners, the four deepest */
    int n = 0;
    for (int k = 0; k < 8; k++) {
        float local[3] = {k & 1 ? b->shape.half[0] : -b->shape.half[0], k & 2 ? b->shape.half[1] : -b->shape.half[1],
                          k & 4 ? b->shape.half[2] : -b->shape.half[2]},
              c[3];
        to_world(c, b->r, local);
        v3_add(c, c, b->p);
        n += sphere(t, c, 0, &all[n], (uint32_t)k);
    }
    for (; count < 4 && count < n; count++) {
        int best = count;
        for (int k = count + 1; k < n; k++)
            if (all[k].depth > all[best].depth) best = k;
        fk_touch s = all[count];
        all[count] = all[best], all[best] = s;
        out[count] = all[count];
    }
    return count;
}
