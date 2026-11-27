/* Terrain (terrain-streaming spec): a heightfield in the world's frame (y up) that bodies and characters rest on.
   Each cell is split into two triangles along the same diagonal; a point's ground is the plane of the triangle
   under it. Only arithmetic and sqrt, so it is deterministic like the rest of the world. */
#include <stdlib.h>
#include <string.h>

#include "physics/physics.h"
#include "physics/vec.h"

void fk_terrain_set(fk_terrain *t, float x0, float z0, float cell, int n, const float *heights) {
    free(t->h);
    memset(t, 0, sizeof *t);
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
static int sphere(const fk_terrain *t, const float c[3], float r, fk_touch *out, uint32_t key) {
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
