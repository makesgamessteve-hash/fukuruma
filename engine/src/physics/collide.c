/* Narrowphase: contacts between spheres, capsules and boxes. Normals point from the first body to the second;
   depth > 0 means the bodies overlap; the point lies midway between the two surfaces. */
#include <string.h>

#include "physics/physics.h"
#include "physics/vec.h"

void fk_body_update(fk_body *b) {
    float x = b->q[0], y = b->q[1], z = b->q[2], w = b->q[3];
    float m[9] = {1 - 2 * (y * y + z * z), 2 * (x * y + z * w),     2 * (x * z - y * w),
                  2 * (x * y - z * w),     1 - 2 * (x * x + z * z), 2 * (y * z + x * w),
                  2 * (x * z + y * w),     2 * (y * z - x * w),     1 - 2 * (x * x + y * y)};
    memcpy(b->r, m, sizeof m);
}

void fk_body_aabb(const fk_body *b, float lo[3], float hi[3]) {
    float ext[3];
    if (b->shape.type == FK_SHAPE_SPHERE) v3_set(ext, b->shape.radius, b->shape.radius, b->shape.radius);
    else if (b->shape.type == FK_SHAPE_CAPSULE)
        for (int i = 0; i < 3; i++) ext[i] = fabsf(axis(b->r, 1)[i]) * b->shape.half[1] + b->shape.radius;
    else
        for (int i = 0; i < 3; i++)
            ext[i] = fabsf(b->r[i]) * b->shape.half[0] + fabsf(b->r[3 + i]) * b->shape.half[1] + fabsf(b->r[6 + i]) * b->shape.half[2];
    v3_sub(lo, b->p, ext);
    v3_add(hi, b->p, ext);
}

static void segment(const fk_body *b, float s0[3], float s1[3]) {
    v3_mad(s0, b->p, axis(b->r, 1), -b->shape.half[1]);
    v3_mad(s1, b->p, axis(b->r, 1), b->shape.half[1]);
}

static void closest_on_segment(const float p[3], const float a[3], const float b[3], float out[3]) {
    float ab[3], ap[3];
    v3_sub(ab, b, a);
    v3_sub(ap, p, a);
    float l2 = v3_dot(ab, ab), t = l2 > 1e-12f ? clampf(v3_dot(ap, ab) / l2, 0, 1) : 0;
    v3_mad(out, a, ab, t);
}

/* The closest points of segments p0-p1 and q0-q1. */
static void closest_segments(const float p0[3], const float p1[3], const float q0[3], const float q1[3], float cp[3], float cq[3]) {
    float d1[3], d2[3], r[3];
    v3_sub(d1, p1, p0);
    v3_sub(d2, q1, q0);
    v3_sub(r, p0, q0);
    float a = v3_dot(d1, d1), e = v3_dot(d2, d2), f = v3_dot(d2, r), s = 0, t = 0;
    if (a <= 1e-12f && e <= 1e-12f) {
        s = t = 0;
    } else if (a <= 1e-12f) {
        t = clampf(f / e, 0, 1);
    } else {
        float c = v3_dot(d1, r);
        if (e <= 1e-12f) {
            s = clampf(-c / a, 0, 1);
        } else {
            float b = v3_dot(d1, d2), denom = a * e - b * b;
            s = denom > 1e-12f ? clampf((b * f - c * e) / denom, 0, 1) : 0;
            t = (b * s + f) / e;
            if (t < 0) t = 0, s = clampf(-c / a, 0, 1);
            else if (t > 1) t = 1, s = clampf((b - c) / a, 0, 1);
        }
    }
    v3_mad(cp, p0, d1, s);
    v3_mad(cq, q0, d2, t);
}

static int spheres(const float pa[3], float ra, const float pb[3], float rb, fk_touch *t, uint32_t key) {
    float d[3];
    v3_sub(d, pb, pa);
    float dist = v3_len(d);
    if (dist >= ra + rb) return 0;
    if (dist > 1e-6f) v3_scale(t->normal, d, 1.0f / dist);
    else v3_set(t->normal, 0, 1, 0);
    t->depth = ra + rb - dist;
    float sa[3];
    v3_mad(sa, pa, t->normal, ra);
    v3_mad(t->point, sa, t->normal, -t->depth * 0.5f);
    t->key = key;
    return 1;
}

/* A sphere (centre c, radius r) against a box: the normal points from the box to the sphere. */
static int sphere_box(const fk_body *box, const float c[3], float r, fk_touch *t, uint32_t key) {
    const float *e = box->shape.half;
    float rel[3], local[3], clamped[3], n[3], surface[3];
    v3_sub(rel, c, box->p);
    to_local(local, box->r, rel);
    for (int i = 0; i < 3; i++) clamped[i] = clampf(local[i], -e[i], e[i]);
    float diff[3];
    v3_sub(diff, local, clamped);
    float dist = v3_len(diff);
    if (dist > 1e-6f) { /* outside */
        if (dist >= r) return 0;
        v3_scale(n, diff, 1.0f / dist);
        t->depth = r - dist;
        v3_copy(surface, clamped);
    } else { /* the centre is inside: out through the nearest face */
        int k = 0;
        float best = e[0] - fabsf(local[0]);
        for (int i = 1; i < 3; i++)
            if (e[i] - fabsf(local[i]) < best) best = e[i] - fabsf(local[i]), k = i;
        v3_set(n, 0, 0, 0);
        n[k] = local[k] < 0 ? -1.0f : 1.0f;
        t->depth = r + best;
        v3_copy(surface, local);
        surface[k] = n[k] * e[k];
    }
    float wn[3], ws[3];
    to_world(wn, box->r, n);
    to_world(ws, box->r, surface);
    v3_add(ws, ws, box->p);
    v3_copy(t->normal, wn);
    v3_mad(t->point, ws, wn, -t->depth * 0.5f);
    t->key = key;
    return 1;
}

/* Signed distance from a point to a box (negative inside). */
static float box_distance(const fk_body *box, const float p[3]) {
    const float *e = box->shape.half;
    float rel[3], local[3], out = 0, in = -1e30f;
    v3_sub(rel, p, box->p);
    to_local(local, box->r, rel);
    for (int i = 0; i < 3; i++) {
        float d = fabsf(local[i]) - e[i];
        if (d > 0) out += d * d;
        if (d > in) in = d;
    }
    return out > 0 ? sqrtf(out) : in;
}

/* A capsule against a box: its end spheres where they touch, else the point of the segment nearest the box (the
   signed distance along the segment is convex, so a ternary search finds it). Normals from the box out. */
static int capsule_box(const fk_body *cap, const fk_body *box, fk_touch out[4]) {
    float s0[3], s1[3], r = cap->shape.radius;
    segment(cap, s0, s1);
    int n = sphere_box(box, s0, r, &out[0], 1);
    n += sphere_box(box, s1, r, &out[n], 2);
    if (n) return n;
    float lo = 0, hi = 1, d[3], p[3];
    v3_sub(d, s1, s0);
    for (int k = 0; k < 40; k++) {
        float m1 = lo + (hi - lo) / 3, m2 = hi - (hi - lo) / 3, a[3], b[3];
        v3_mad(a, s0, d, m1);
        v3_mad(b, s0, d, m2);
        if (box_distance(box, a) < box_distance(box, b)) hi = m2;
        else lo = m1;
    }
    v3_mad(p, s0, d, (lo + hi) * 0.5f);
    return sphere_box(box, p, r, &out[0], 3);
}

/* Keeps dot(normal, p) <= offset (Sutherland-Hodgman). */
static int clip(float in[][3], int n, const float normal[3], float offset, float out[][3]) {
    int m = 0;
    for (int i = 0; i < n; i++) {
        const float *a = in[i], *b = in[(i + 1) % n];
        float da = v3_dot(normal, a) - offset, db = v3_dot(normal, b) - offset;
        if (da <= 0) v3_copy(out[m++], a);
        if ((da < 0 && db > 0) || (da > 0 && db < 0)) {
            float t = da / (da - db), ab[3];
            v3_sub(ab, b, a);
            v3_mad(out[m++], a, ab, t);
        }
    }
    return m;
}

static float sgn(float x) { return x < 0 ? -1.0f : 1.0f; }

static int box_box(const fk_body *A, const fk_body *B, fk_touch out[4]) {
    const float *ea = A->shape.half, *eb = B->shape.half;
    float d[3], C[3][3], absC[3][3];
    v3_sub(d, B->p, A->p);
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++) C[i][j] = v3_dot(axis(A->r, i), axis(B->r, j)), absC[i][j] = fabsf(C[i][j]) + 1e-6f;
    float best = 1e30f, n[3] = {0, 1, 0};
    int best_axis = -1;
    for (int i = 0; i < 3; i++) { /* A's faces */
        float rb = eb[0] * absC[i][0] + eb[1] * absC[i][1] + eb[2] * absC[i][2], dist = v3_dot(d, axis(A->r, i));
        float overlap = ea[i] + rb - fabsf(dist);
        if (overlap < 0) return 0;
        if (overlap < best) best = overlap, best_axis = i, v3_scale(n, axis(A->r, i), sgn(dist));
    }
    for (int j = 0; j < 3; j++) { /* B's faces, only when clearly better: steadier stacks */
        float ra = ea[0] * absC[0][j] + ea[1] * absC[1][j] + ea[2] * absC[2][j], dist = v3_dot(d, axis(B->r, j));
        float overlap = ra + eb[j] - fabsf(dist);
        if (overlap < 0) return 0;
        if (overlap * 1.05f + 0.001f < best) best = overlap, best_axis = 3 + j, v3_scale(n, axis(B->r, j), sgn(dist));
    }
    float face_best = best;
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++) { /* edge pairs */
            float L[3];
            v3_cross(L, axis(A->r, i), axis(B->r, j));
            float len = v3_len(L);
            if (len < 1e-4f) continue;
            v3_scale(L, L, 1.0f / len);
            float ra = 0, rb = 0;
            for (int k = 0; k < 3; k++) ra += ea[k] * fabsf(v3_dot(axis(A->r, k), L)), rb += eb[k] * fabsf(v3_dot(axis(B->r, k), L));
            float dist = v3_dot(d, L), overlap = ra + rb - fabsf(dist);
            if (overlap < 0) return 0;
            if (overlap * 1.05f + 0.01f < face_best && overlap < best) best = overlap, best_axis = 6 + i * 3 + j, v3_scale(n, L, sgn(dist));
        }
    if (best_axis >= 6) { /* edge against edge: one contact between the two closest edges */
        int i = (best_axis - 6) / 3, j = (best_axis - 6) % 3;
        float ca[3], cb[3], a0[3], a1[3], b0[3], b1[3], pa[3], pb[3];
        v3_copy(ca, A->p);
        v3_copy(cb, B->p);
        for (int k = 0; k < 3; k++) {
            if (k != i) v3_mad(ca, ca, axis(A->r, k), sgn(v3_dot(axis(A->r, k), n)) * ea[k]);
            if (k != j) v3_mad(cb, cb, axis(B->r, k), -sgn(v3_dot(axis(B->r, k), n)) * eb[k]);
        }
        v3_mad(a0, ca, axis(A->r, i), -ea[i]);
        v3_mad(a1, ca, axis(A->r, i), ea[i]);
        v3_mad(b0, cb, axis(B->r, j), -eb[j]);
        v3_mad(b1, cb, axis(B->r, j), eb[j]);
        closest_segments(a0, a1, b0, b1, pa, pb);
        v3_add(out[0].point, pa, pb);
        v3_scale(out[0].point, out[0].point, 0.5f);
        v3_copy(out[0].normal, n);
        out[0].depth = best;
        out[0].key = (uint32_t)best_axis << 24;
        return 1;
    }
    /* A face against a face: clip the incident face by the reference face's sides. */
    const fk_body *R = best_axis < 3 ? A : B, *I = best_axis < 3 ? B : A;
    int k = best_axis % 3;
    float nr[3];
    v3_scale(nr, n, best_axis < 3 ? 1.0f : -1.0f); /* out of the reference face, towards the incident box */
    const float *er = R->shape.half, *ei = I->shape.half;
    float fc[3];
    v3_mad(fc, R->p, nr, er[k]);
    int m = 0;
    float most = -1;
    for (int c = 0; c < 3; c++)
        if (fabsf(v3_dot(axis(I->r, c), nr)) > most) most = fabsf(v3_dot(axis(I->r, c), nr)), m = c;
    float ni[3], ic[3], poly[8][3], tmp[8][3];
    v3_scale(ni, axis(I->r, m), -sgn(v3_dot(axis(I->r, m), nr)));
    v3_mad(ic, I->p, ni, ei[m]);
    int m1 = (m + 1) % 3, m2 = (m + 2) % 3;
    static const float corners[4][2] = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}};
    for (int c = 0; c < 4; c++) {
        v3_mad(poly[c], ic, axis(I->r, m1), corners[c][0] * ei[m1]);
        v3_mad(poly[c], poly[c], axis(I->r, m2), corners[c][1] * ei[m2]);
    }
    int count = 4, k1 = (k + 1) % 3, k2 = (k + 2) % 3;
    const int sides[2] = {k1, k2};
    for (int s = 0; s < 2 && count; s++) {
        const float *u = axis(R->r, sides[s]);
        float neg[3], c0 = v3_dot(u, R->p);
        count = clip(poly, count, u, c0 + er[sides[s]], tmp);
        v3_scale(neg, u, -1);
        count = clip(tmp, count, neg, -c0 + er[sides[s]], poly);
    }
    fk_touch all[8];
    int found = 0;
    for (int c = 0; c < count; c++) {
        float diff[3];
        v3_sub(diff, fc, poly[c]);
        float depth = v3_dot(nr, diff);
        bool twin = false; /* faces that line up give the same point twice */
        for (int o = 0; o < c; o++) {
            float dd[3];
            v3_sub(dd, poly[o], poly[c]);
            twin = twin || fabsf(dd[0]) + fabsf(dd[1]) + fabsf(dd[2]) < 2e-3f;
        }
        if (depth <= 0 || twin) continue;
        fk_touch *t = &all[found++];
        v3_mad(t->point, poly[c], nr, depth * 0.5f);
        v3_copy(t->normal, n);
        t->depth = depth;
        /* The key: where on the reference face, in 5 cm cells, so it survives small motions between steps. */
        float rel[3];
        v3_sub(rel, poly[c], R->p);
        int qu = (int)floorf(v3_dot(rel, axis(R->r, k1)) * 20 + 0.5f), qv = (int)floorf(v3_dot(rel, axis(R->r, k2)) * 20 + 0.5f);
        t->key = (uint32_t)best_axis << 24 | ((uint32_t)qu & 0xfff) << 12 | ((uint32_t)qv & 0xfff);
    }
    if (found <= 4) {
        memcpy(out, all, (size_t)found * sizeof *all);
        return found;
    }
    /* More than four: the deepest, then each time the one farthest from those kept. */
    bool used[8] = {false};
    int deepest = 0;
    for (int c = 1; c < found; c++)
        if (all[c].depth > all[deepest].depth) deepest = c;
    out[0] = all[deepest], used[deepest] = true;
    for (int o = 1; o < 4; o++) {
        int pick = -1;
        float far = -1;
        for (int c = 0; c < found; c++) {
            if (used[c]) continue;
            float nearest = 1e30f;
            for (int q = 0; q < o; q++) {
                float diff[3];
                v3_sub(diff, all[c].point, out[q].point);
                if (v3_dot(diff, diff) < nearest) nearest = v3_dot(diff, diff);
            }
            if (nearest > far) far = nearest, pick = c;
        }
        out[o] = all[pick], used[pick] = true;
    }
    return 4;
}

int fk_collide(const fk_body *a, const fk_body *b, fk_touch out[4]) {
    bool swap = a->shape.type > b->shape.type;
    if (swap) {
        const fk_body *t = a;
        a = b, b = t;
    }
    int n = 0;
    float s0[3], s1[3], q[3], p0[3], p1[3], cp[3], cq[3];
    switch (a->shape.type * 3 + b->shape.type) {
    case FK_SHAPE_SPHERE * 3 + FK_SHAPE_SPHERE:
        n = spheres(a->p, a->shape.radius, b->p, b->shape.radius, out, 0);
        break;
    case FK_SHAPE_SPHERE * 3 + FK_SHAPE_CAPSULE:
        segment(b, s0, s1);
        closest_on_segment(a->p, s0, s1, q);
        n = spheres(a->p, a->shape.radius, q, b->shape.radius, out, 0);
        break;
    case FK_SHAPE_SPHERE * 3 + FK_SHAPE_BOX:
        n = sphere_box(b, a->p, a->shape.radius, out, 0);
        swap = !swap; /* sphere_box's normal points from the box (b) to the sphere (a) */
        break;
    case FK_SHAPE_CAPSULE * 3 + FK_SHAPE_CAPSULE:
        segment(a, p0, p1);
        segment(b, s0, s1);
        closest_segments(p0, p1, s0, s1, cp, cq);
        n = spheres(cp, a->shape.radius, cq, b->shape.radius, out, 0);
        break;
    case FK_SHAPE_CAPSULE * 3 + FK_SHAPE_BOX:
        n = capsule_box(a, b, out);
        swap = !swap;
        break;
    default:
        n = box_box(a, b, out);
        break;
    }
    if (swap)
        for (int i = 0; i < n; i++) v3_scale(out[i].normal, out[i].normal, -1);
    return n;
}
