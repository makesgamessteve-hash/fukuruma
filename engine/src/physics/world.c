/* The physics world: bodies, broadphase grid, contact solver (sequential impulses), sleeping islands and
   kinematic characters. Every loop runs in creation order or in sorted order, so a step is deterministic. */
#include <stdlib.h>
#include <string.h>

#include "physics/physics.h"
#include "physics/vec.h"

#define CELL 4.0f         /* broadphase cell size, metres */
#define BIG_CELLS 64      /* bodies covering more cells are tested against every body instead */
#define MARGIN 0.02f      /* AABBs grow by this much, so resting contacts are found */
#define ITERATIONS 10     /* velocity iterations per step */
#define BAUMGARTE 0.2f    /* fraction of the overlap removed per step */
#define SLOP 0.01f        /* overlap that is left alone, so resting contacts do not jitter */
#define SLEEP_V2 0.0025f  /* squared speed (and spin) below which a body counts as still */
#define SLEEP_STEPS 30    /* still for this many steps in a row (and its whole island): asleep */

typedef struct {
    int a, b; /* body indices */
    float point[3], normal[3], ra[3], rb[3], t1[3], t2[3];
    float depth, normal_mass, tangent_mass[2], target, friction, jn, jt[2];
    uint32_t key;
    bool fresh; /* no warm start: a new touch */
} contact;

typedef struct {
    int64_t cell;
    int body;
} cell_entry;

struct fk_world {
    float gravity[3];
    fk_body *bodies;
    int n, cap;
    uint32_t next_id;
    contact *contacts;
    int ncontacts, contact_cap;
    fk_cached *cache;
    int ncache, cache_cap;
    fk_impact *impacts;
    int nimpacts, impact_cap;
    cell_entry *cells;
    int ncells, cell_cap;
    int *pairs;
    int npairs, pair_cap;
    int *island, *island_still, island_cap;
    fk_terrain terrain;
    fk_body ground; /* the terrain's side of its contacts (index -1): static, id 0 */
};

static fk_body *body_at(fk_world *w, int i) { return i < 0 ? &w->ground : &w->bodies[i]; }

static void *grow(void *p, int *cap, int need, size_t size) {
    if (need <= *cap) return p;
    int c = *cap ? *cap : 16;
    while (c < need) c *= 2;
    void *q = realloc(p, (size_t)c * size);
    if (!q) abort(); /* out of memory in the physics step: nothing sensible to continue with */
    *cap = c;
    return q;
}

fk_world *fk_world_create(const float gravity[3]) {
    fk_world *w = calloc(1, sizeof *w);
    if (!w) abort();
    v3_copy(w->gravity, gravity);
    w->next_id = 1;
    w->ground.kind = FK_BODY_STATIC, w->ground.q[3] = 1, w->ground.friction = 0.8f;
    fk_body_update(&w->ground);
    return w;
}

void fk_world_destroy(fk_world *w) {
    if (!w) return;
    free(w->bodies), free(w->contacts), free(w->cache), free(w->impacts), free(w->cells), free(w->pairs);
    free(w->island), free(w->island_still);
    fk_terrain_set(&w->terrain, 0, 0, 0, 0, NULL);
    free(w->terrain.digs);
    free(w);
}

void fk_world_gravity(fk_world *w, const float gravity[3]) {
    v3_copy(w->gravity, gravity);
    for (int i = 0; i < w->n; i++) w->bodies[i].asleep = false, w->bodies[i].still = 0;
}

const float *fk_world_get_gravity(const fk_world *w) { return w->gravity; }

void fk_world_terrain(fk_world *w, float x0, float z0, float cell, int n, const float *heights, float friction) {
    fk_terrain_set(&w->terrain, x0, z0, cell, n, heights);
    w->ground.friction = friction;
}

const fk_terrain *fk_world_get_terrain(const fk_world *w) { return &w->terrain; }

void fk_world_digs(fk_world *w, const float *digs, int n, bool wake) {
    free(w->terrain.digs);
    w->terrain.digs = NULL, w->terrain.ndigs = 0;
    if (n > 0) {
        w->terrain.digs = malloc((size_t)n * 4 * sizeof(float));
        if (!w->terrain.digs) abort();
        memcpy(w->terrain.digs, digs, (size_t)n * 4 * sizeof(float));
        w->terrain.ndigs = n;
    }
    if (wake)
        for (int i = 0; i < w->n; i++) w->bodies[i].asleep = false, w->bodies[i].still = 0;
}
int fk_world_count(const fk_world *w) { return w->n; }
fk_body *fk_world_bodies(fk_world *w) { return w->bodies; }
uint32_t fk_world_next_id(const fk_world *w) { return w->next_id; }

const fk_cached *fk_world_cache(const fk_world *w, int *count) {
    *count = w->ncache;
    return w->cache;
}

static void set_mass(fk_body *b, float mass) {
    memset(b->inv_inertia, 0, sizeof b->inv_inertia);
    b->inv_mass = 0;
    if (b->kind != FK_BODY_DYNAMIC || !(mass > 0)) return;
    float r = b->shape.radius, I[3];
    if (b->shape.type == FK_SHAPE_SPHERE) {
        I[0] = I[1] = I[2] = 0.4f * mass * r * r;
    } else if (b->shape.type == FK_SHAPE_CAPSULE) { /* as a cylinder as long as the whole capsule */
        float l = 2 * (b->shape.half[1] + r);
        I[0] = I[2] = mass * (3 * r * r + l * l) / 12, I[1] = 0.5f * mass * r * r;
    } else {
        const float *e = b->shape.half;
        I[0] = mass * 4 * (e[1] * e[1] + e[2] * e[2]) / 12, I[1] = mass * 4 * (e[0] * e[0] + e[2] * e[2]) / 12,
        I[2] = mass * 4 * (e[0] * e[0] + e[1] * e[1]) / 12;
    }
    b->inv_mass = 1 / mass;
    for (int i = 0; i < 3; i++) b->inv_inertia[i] = I[i] > 0 ? 1 / I[i] : 0;
}

static fk_body *push_body(fk_world *w, const fk_body *init) {
    w->bodies = grow(w->bodies, &w->cap, w->n + 1, sizeof *w->bodies);
    fk_body *b = &w->bodies[w->n++];
    *b = *init;
    fk_body_update(b);
    return b;
}

uint32_t fk_world_add(fk_world *w, const fk_body *init, float mass) {
    fk_body *b = push_body(w, init);
    float l = sqrtf(b->q[0] * b->q[0] + b->q[1] * b->q[1] + b->q[2] * b->q[2] + b->q[3] * b->q[3]);
    if (l > 1e-6f)
        for (int i = 0; i < 4; i++) b->q[i] /= l;
    else
        b->q[0] = b->q[1] = b->q[2] = 0, b->q[3] = 1;
    set_mass(b, mass);
    fk_body_update(b);
    b->id = w->next_id++;
    return b->id;
}

static int index_of(const fk_world *w, uint32_t id) { /* bodies stay sorted by id: binary search */
    int lo = 0, hi = w->n - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (w->bodies[mid].id == id) return mid;
        if (w->bodies[mid].id < id) lo = mid + 1;
        else hi = mid - 1;
    }
    return -1;
}

fk_body *fk_world_body(fk_world *w, uint32_t id) {
    int i = index_of(w, id);
    return i < 0 ? NULL : &w->bodies[i];
}

bool fk_world_remove(fk_world *w, uint32_t id) {
    int i = index_of(w, id);
    if (i < 0) return false;
    memmove(&w->bodies[i], &w->bodies[i + 1], (size_t)(w->n - i - 1) * sizeof *w->bodies);
    w->n--;
    for (int k = 0; k < w->n; k++) w->bodies[k].asleep = false, w->bodies[k].still = 0; /* what rested on it falls */
    return true;
}

void fk_world_wake(fk_world *w, fk_body *b) {
    (void)w;
    b->asleep = false;
    b->still = 0;
}

void fk_world_clear(fk_world *w, uint32_t next_id) {
    w->n = 0, w->ncache = 0;
    w->next_id = next_id;
}

bool fk_world_put(fk_world *w, const fk_body *b) {
    if (b->id == 0 || b->id >= w->next_id || (w->n && w->bodies[w->n - 1].id >= b->id)) return false;
    push_body(w, b);
    return true;
}

static int cache_order(const void *x, const void *y) {
    const fk_cached *a = x, *b = y;
    if (a->a != b->a) return a->a < b->a ? -1 : 1;
    if (a->b != b->b) return a->b < b->b ? -1 : 1;
    return a->key < b->key ? -1 : a->key > b->key;
}

void fk_world_put_cache(fk_world *w, const fk_cached *c, int count) {
    w->cache = grow(w->cache, &w->cache_cap, count, sizeof *w->cache);
    memcpy(w->cache, c, (size_t)count * sizeof *c);
    w->ncache = count;
    qsort(w->cache, (size_t)count, sizeof *c, cache_order);
}

/* Broadphase -------------------------------------------------------------------------------------------- */

static int entry_order(const void *x, const void *y) {
    const cell_entry *a = x, *b = y;
    if (a->cell != b->cell) return a->cell < b->cell ? -1 : 1;
    return a->body - b->body;
}

static int pair_order(const void *x, const void *y) {
    const int *a = x, *b = y;
    if (a[0] != b[0]) return a[0] - b[0];
    return a[1] - b[1];
}

static bool movable(const fk_body *b) { return b->kind == FK_BODY_DYNAMIC; }

static bool interesting(const fk_body *a, const fk_body *b) { /* at least one awake dynamic body, or a waker */
    if (!movable(a) && !movable(b)) return false;
    bool awake_a = movable(a) && !a->asleep, awake_b = movable(b) && !b->asleep;
    bool moving_a = !movable(a) && v3_dot(a->v, a->v) > 0, moving_b = !movable(b) && v3_dot(b->v, b->v) > 0;
    return awake_a || awake_b || moving_a || moving_b;
}

static void add_pair(fk_world *w, int i, int j) {
    if (i == j) return;
    if (i > j) {
        int t = i;
        i = j, j = t;
    }
    if (!interesting(&w->bodies[i], &w->bodies[j])) return;
    w->pairs = grow(w->pairs, &w->pair_cap, 2 * (w->npairs + 1), sizeof *w->pairs);
    w->pairs[2 * w->npairs] = i, w->pairs[2 * w->npairs + 1] = j;
    w->npairs++;
}

static void broadphase(fk_world *w, float (*lo)[3], float (*hi)[3]) {
    w->ncells = 0, w->npairs = 0;
    int nbig = 0;
    int *big = w->island; /* scratch: big bodies' indices */
    for (int i = 0; i < w->n; i++) {
        int c0[3], c1[3];
        long long cells = 1;
        for (int k = 0; k < 3; k++) {
            c0[k] = (int)floorf(lo[i][k] / CELL), c1[k] = (int)floorf(hi[i][k] / CELL);
            cells *= (long long)(c1[k] - c0[k] + 1);
        }
        if (cells > BIG_CELLS) {
            big[nbig++] = i;
            continue;
        }
        for (int x = c0[0]; x <= c1[0]; x++)
            for (int y = c0[1]; y <= c1[1]; y++)
                for (int z = c0[2]; z <= c1[2]; z++) {
                    w->cells = grow(w->cells, &w->cell_cap, w->ncells + 1, sizeof *w->cells);
                    int64_t key = ((int64_t)(x & 0x1fffff) << 42) | ((int64_t)(y & 0x1fffff) << 21) | (int64_t)(z & 0x1fffff);
                    w->cells[w->ncells++] = (cell_entry){key, i};
                }
    }
    qsort(w->cells, (size_t)w->ncells, sizeof *w->cells, entry_order);
    for (int s = 0; s < w->ncells;) {
        int e = s;
        while (e < w->ncells && w->cells[e].cell == w->cells[s].cell) e++;
        for (int a = s; a < e; a++)
            for (int b = a + 1; b < e; b++) add_pair(w, w->cells[a].body, w->cells[b].body);
        s = e;
    }
    for (int k = 0; k < nbig; k++)
        for (int i = 0; i < w->n; i++)
            if (i != big[k]) add_pair(w, big[k], i);
    qsort(w->pairs, (size_t)w->npairs, 2 * sizeof *w->pairs, pair_order);
    int m = 0; /* without duplicates, and only pairs whose boxes overlap */
    for (int p = 0; p < w->npairs; p++) {
        int i = w->pairs[2 * p], j = w->pairs[2 * p + 1];
        if (m && w->pairs[2 * (m - 1)] == i && w->pairs[2 * (m - 1) + 1] == j) continue;
        bool overlap = true;
        for (int k = 0; k < 3; k++) overlap = overlap && lo[i][k] <= hi[j][k] && lo[j][k] <= hi[i][k];
        if (!overlap) continue;
        w->pairs[2 * m] = i, w->pairs[2 * m + 1] = j;
        m++;
    }
    w->npairs = m;
}

/* Solver ---------------------------------------------------------------------------------------------- */

static void inv_inertia_world(const fk_body *b, const float v[3], float out[3]) {
    float l[3];
    to_local(l, b->r, v);
    for (int i = 0; i < 3; i++) l[i] *= b->inv_inertia[i];
    to_world(out, b->r, l);
}

static float effective_mass(const fk_body *a, const fk_body *b, const float ra[3], const float rb[3], const float n[3]) {
    float c[3], i[3], k = a->inv_mass + b->inv_mass;
    v3_cross(c, ra, n);
    inv_inertia_world(a, c, i);
    v3_cross(c, i, ra);
    k += v3_dot(c, n);
    v3_cross(c, rb, n);
    inv_inertia_world(b, c, i);
    v3_cross(c, i, rb);
    k += v3_dot(c, n);
    return k > 1e-12f ? 1 / k : 0;
}

static void relative_velocity(const fk_body *a, const fk_body *b, const contact *c, float out[3]) {
    float wa[3], wb[3];
    v3_cross(wa, a->w, c->ra);
    v3_cross(wb, b->w, c->rb);
    for (int k = 0; k < 3; k++) out[k] = (b->v[k] + wb[k]) - (a->v[k] + wa[k]);
}

static void apply(fk_body *a, fk_body *b, const contact *c, const float dir[3], float j) {
    float p[3], t[3], d[3];
    v3_scale(p, dir, j);
    v3_mad(a->v, a->v, p, -a->inv_mass);
    v3_mad(b->v, b->v, p, b->inv_mass);
    v3_cross(t, c->ra, p);
    inv_inertia_world(a, t, d);
    v3_sub(a->w, a->w, d);
    v3_cross(t, c->rb, p);
    inv_inertia_world(b, t, d);
    v3_add(b->w, b->w, d);
}

static const fk_cached *find_cache(const fk_world *w, uint32_t a, uint32_t b, uint32_t key) {
    fk_cached k = {a, b, key, 0, {0, 0}};
    return w->ncache ? bsearch(&k, w->cache, (size_t)w->ncache, sizeof k, cache_order) : NULL;
}

static void tangents(const float n[3], float t1[3], float t2[3]) {
    if (fabsf(n[0]) >= 0.57735f) v3_set(t1, n[1], -n[0], 0);
    else v3_set(t1, 0, n[2], -n[1]);
    v3_norm(t1, t1);
    v3_cross(t2, n, t1);
}

static int find(int *parent, int i) {
    while (parent[i] != i) i = parent[i] = parent[parent[i]];
    return i;
}

static void update_sleep(fk_world *w) {
    w->island = grow(w->island, &w->island_cap, w->n, sizeof *w->island);
    int still_cap = w->island_cap;
    w->island_still = realloc(w->island_still, (size_t)still_cap * sizeof *w->island_still);
    if (!w->island_still) abort();
    for (int i = 0; i < w->n; i++) {
        fk_body *b = &w->bodies[i];
        w->island[i] = i;
        if (!movable(b) || b->asleep) continue;
        bool still = v3_dot(b->v, b->v) < SLEEP_V2 && v3_dot(b->w, b->w) < SLEEP_V2;
        b->still = still ? b->still + 1 : 0;
    }
    for (int c = 0; c < w->ncontacts; c++) {
        const contact *k = &w->contacts[c];
        if (k->a >= 0 && movable(&w->bodies[k->a]) && movable(&w->bodies[k->b])) {
            int ra = find(w->island, k->a), rb = find(w->island, k->b);
            if (ra != rb) w->island[ra < rb ? rb : ra] = ra < rb ? ra : rb;
        }
    }
    for (int i = 0; i < w->n; i++) w->island_still[i] = 1 << 30;
    for (int i = 0; i < w->n; i++) {
        const fk_body *b = &w->bodies[i];
        if (!movable(b)) continue;
        int r = find(w->island, i), s = b->asleep ? SLEEP_STEPS : b->still;
        if (s < w->island_still[r]) w->island_still[r] = s;
    }
    for (int i = 0; i < w->n; i++) {
        fk_body *b = &w->bodies[i];
        if (!movable(b) || b->asleep || w->island_still[find(w->island, i)] < SLEEP_STEPS) continue;
        b->asleep = true;
        v3_set(b->v, 0, 0, 0);
        v3_set(b->w, 0, 0, 0);
    }
}

const fk_impact *fk_world_step(fk_world *w, float dt, float min_impulse, int *count) {
    *count = 0;
    w->nimpacts = 0;
    if (!(dt > 0)) return w->impacts;
    for (int i = 0; i < w->n; i++) {
        fk_body *b = &w->bodies[i];
        fk_body_update(b);
        if (movable(b) && !b->asleep) v3_mad(b->v, b->v, b->own_gravity ? b->gravity : w->gravity, dt);
    }
    /* Broadphase and narrowphase. */
    w->island = grow(w->island, &w->island_cap, w->n + 1, sizeof *w->island);
    float (*lo)[3] = malloc((size_t)(w->n + 1) * sizeof *lo), (*hi)[3] = malloc((size_t)(w->n + 1) * sizeof *hi);
    if (!lo || !hi) abort();
    for (int i = 0; i < w->n; i++) {
        fk_body_aabb(&w->bodies[i], lo[i], hi[i]);
        for (int k = 0; k < 3; k++) lo[i][k] -= MARGIN, hi[i][k] += MARGIN;
    }
    broadphase(w, lo, hi);
    free(lo), free(hi);
    w->ncontacts = 0;
    for (int p = 0; p < w->npairs; p++) {
        int ia = w->pairs[2 * p], ib = w->pairs[2 * p + 1];
        fk_body *a = &w->bodies[ia], *b = &w->bodies[ib];
        fk_touch t[4];
        int n = fk_collide(a, b, t);
        if (!n) continue;
        if (a->asleep) fk_world_wake(w, a);
        if (b->asleep) fk_world_wake(w, b);
        w->contacts = grow(w->contacts, &w->contact_cap, w->ncontacts + n, sizeof *w->contacts);
        for (int k = 0; k < n; k++) {
            contact *c = &w->contacts[w->ncontacts++];
            memset(c, 0, sizeof *c);
            c->a = ia, c->b = ib, c->key = t[k].key, c->depth = t[k].depth;
            v3_copy(c->point, t[k].point);
            v3_copy(c->normal, t[k].normal);
        }
    }
    for (int i = 0; i < w->n; i++) { /* the terrain under awake bodies */
        fk_body *b = &w->bodies[i];
        if (!movable(b) || b->asleep) continue;
        fk_touch t[4];
        int n = fk_terrain_collide(&w->terrain, b, t);
        w->contacts = grow(w->contacts, &w->contact_cap, w->ncontacts + n, sizeof *w->contacts);
        for (int k = 0; k < n; k++) {
            contact *c = &w->contacts[w->ncontacts++];
            memset(c, 0, sizeof *c);
            c->a = -1, c->b = i, c->key = t[k].key, c->depth = t[k].depth;
            v3_copy(c->point, t[k].point);
            v3_copy(c->normal, t[k].normal);
        }
    }
    /* Prepare and warm start. */
    for (int k = 0; k < w->ncontacts; k++) {
        contact *c = &w->contacts[k];
        fk_body *a = body_at(w, c->a), *b = body_at(w, c->b);
        v3_sub(c->ra, c->point, a->p);
        v3_sub(c->rb, c->point, b->p);
        tangents(c->normal, c->t1, c->t2);
        c->normal_mass = effective_mass(a, b, c->ra, c->rb, c->normal);
        c->tangent_mass[0] = effective_mass(a, b, c->ra, c->rb, c->t1);
        c->tangent_mass[1] = effective_mass(a, b, c->ra, c->rb, c->t2);
        c->friction = sqrtf(a->friction * b->friction);
        float vrel[3];
        relative_velocity(a, b, c, vrel);
        float vn = v3_dot(vrel, c->normal), e = a->restitution > b->restitution ? a->restitution : b->restitution;
        float bounce = vn < -1.0f ? -e * vn : 0, push = BAUMGARTE / dt * (c->depth > SLOP ? c->depth - SLOP : 0);
        c->target = bounce > push ? bounce : push;
        const fk_cached *old = find_cache(w, a->id, b->id, c->key);
        c->fresh = !old;
        if (old) {
            c->jn = old->jn, c->jt[0] = old->jt[0], c->jt[1] = old->jt[1];
            apply(a, b, c, c->normal, c->jn);
            apply(a, b, c, c->t1, c->jt[0]);
            apply(a, b, c, c->t2, c->jt[1]);
        }
    }
    /* Velocity iterations: friction, then the normal impulse that keeps the bodies apart. */
    for (int it = 0; it < ITERATIONS; it++)
        for (int k = 0; k < w->ncontacts; k++) {
            contact *c = &w->contacts[k];
            fk_body *a = body_at(w, c->a), *b = body_at(w, c->b);
            float vrel[3];
            const float *dirs[2] = {c->t1, c->t2};
            for (int t = 0; t < 2; t++) {
                relative_velocity(a, b, c, vrel);
                float limit = c->friction * c->jn, old = c->jt[t];
                c->jt[t] = clampf(old - c->tangent_mass[t] * v3_dot(vrel, dirs[t]), -limit, limit);
                apply(a, b, c, dirs[t], c->jt[t] - old);
            }
            relative_velocity(a, b, c, vrel);
            float old = c->jn;
            c->jn = old + c->normal_mass * (c->target - v3_dot(vrel, c->normal));
            if (c->jn < 0) c->jn = 0;
            apply(a, b, c, c->normal, c->jn - old);
        }
    /* Integrate positions. Characters are moved by fk_world_move instead. */
    for (int i = 0; i < w->n; i++) {
        fk_body *b = &w->bodies[i];
        if (b->kind == FK_BODY_STATIC || b->kind == FK_BODY_CHARACTER || b->asleep) continue;
        v3_mad(b->p, b->p, b->v, dt);
        float *q = b->q, h = 0.5f * dt;
        float dq[4] = {h * (b->w[0] * q[3] + b->w[1] * q[2] - b->w[2] * q[1]), h * (b->w[1] * q[3] + b->w[2] * q[0] - b->w[0] * q[2]),
                       h * (b->w[2] * q[3] + b->w[0] * q[1] - b->w[1] * q[0]), h * (-b->w[0] * q[0] - b->w[1] * q[1] - b->w[2] * q[2])};
        float l = 0;
        for (int k = 0; k < 4; k++) q[k] += dq[k], l += q[k] * q[k];
        l = 1 / sqrtf(l);
        for (int k = 0; k < 4; k++) q[k] *= l;
        fk_body_update(b);
    }
    update_sleep(w);
    /* Remember the impulses for the next step; report new touches. */
    w->cache = grow(w->cache, &w->cache_cap, w->ncontacts, sizeof *w->cache);
    w->ncache = 0;
    for (int k = 0; k < w->ncontacts; k++) {
        const contact *c = &w->contacts[k];
        const fk_body *a = body_at(w, c->a), *b = body_at(w, c->b);
        w->cache[w->ncache++] = (fk_cached){a->id, b->id, c->key, c->jn, {c->jt[0], c->jt[1]}};
        if (c->fresh && c->jn > min_impulse) {
            w->impacts = grow(w->impacts, &w->impact_cap, w->nimpacts + 1, sizeof *w->impacts);
            fk_impact *m = &w->impacts[w->nimpacts++];
            m->a = a->id, m->b = b->id, m->impulse = c->jn;
            v3_copy(m->point, c->point);
            v3_copy(m->normal, c->normal);
        }
    }
    qsort(w->cache, (size_t)w->ncache, sizeof *w->cache, cache_order);
    *count = w->nimpacts;
    return w->impacts;
}

/* Characters ------------------------------------------------------------------------------------------ */

typedef struct {
    bool grounded;
} move_result;

/* Is there room just above an edge, a little way into the obstacle? Then the edge is the top of a step, not a
   point on a steep slope or a wall. */
static bool step_top(const fk_body *o, const float edge[3], const float normal[3], const float up[3]) {
    fk_body probe;
    memset(&probe, 0, sizeof probe);
    probe.shape.type = FK_SHAPE_SPHERE, probe.shape.radius = 0.005f, probe.q[3] = 1;
    float flat[3];
    v3_mad(flat, normal, up, -v3_dot(normal, up));
    v3_norm(flat, flat);
    v3_mad(probe.p, edge, flat, -0.05f);
    v3_mad(probe.p, probe.p, up, 0.02f);
    fk_body_update(&probe);
    fk_touch t[4];
    return fk_collide(o, &probe, t) == 0;
}

/* Pushes the character out of one touch with obstacle o (normal from o to the character). */
static void push_out(fk_world *w, fk_body *c, const fk_body *o, const fk_touch *t, const float up[3], move_result *r) {
    float radius = c->shape.radius, half = c->shape.half[1];
    float along = v3_dot(t->normal, up), edge[3], foot[3], sphere[3], rel[3];
    v3_mad(edge, t->point, t->normal, 0.5f * t->depth); /* on the obstacle's surface */
    v3_mad(sphere, c->p, up, -half);                      /* the lower end's centre */
    v3_mad(foot, sphere, up, -radius);
    v3_sub(rel, edge, foot);
    float height = v3_dot(rel, up);
    if (along >= c->slope_cos) {
        v3_mad(c->p, c->p, up, t->depth / along);
        r->grounded = true;
    } else if (o != &w->ground && height > 0.01f && height <= c->step && height < 0.9f * radius &&
               step_top(o, edge, t->normal, up)) {
        /* onto the step: lift the lower end until the edge lies on its surface */
        float d[3];
        v3_sub(d, sphere, edge);
        float du = v3_dot(d, up), disc = du * du - v3_dot(d, d) + radius * radius;
        v3_mad(c->p, c->p, up, -du + sqrtf(disc > 0 ? disc : 0));
        r->grounded = true;
    } else {
        v3_mad(c->p, c->p, t->normal, t->depth);
    }
}

/* Pushes the character out of what it overlaps. Walkable ground lifts it straight up (no sliding down slopes),
   so do the edges of steps no higher than its step height; walls and ceilings push it along their normals.
   Bodies light enough to push are left to the solver. The terrain counts as walkable ground or a wall. */
static move_result resolve(fk_world *w, fk_body *c, const float up[3]) {
    move_result r = {false};
    for (int it = 0; it < 4; it++) {
        bool moved = false;
        float lo[3], hi[3];
        fk_body_aabb(c, lo, hi);
        for (int i = 0; i < w->n; i++) {
            fk_body *o = &w->bodies[i];
            if (o == c || o->kind == FK_BODY_CHARACTER) continue;
            if (o->kind == FK_BODY_DYNAMIC && o->inv_mass > 0 && 1 / o->inv_mass <= c->push_mass) continue;
            float olo[3], ohi[3];
            fk_body_aabb(o, olo, ohi);
            bool overlap = true;
            for (int k = 0; k < 3; k++) overlap = overlap && lo[k] <= ohi[k] && olo[k] <= hi[k];
            if (!overlap) continue;
            fk_touch t[4];
            int n = fk_collide(o, c, t);
            for (int k = 0; k < n; k++) {
                if (t[k].depth <= 1e-4f) continue;
                push_out(w, c, o, &t[k], up, &r);
                moved = true;
                fk_body_aabb(c, lo, hi);
            }
        }
        fk_touch t[4];
        int n = fk_terrain_collide(&w->terrain, c, t);
        for (int k = 0; k < n; k++) {
            if (t[k].depth <= 1e-4f) continue;
            push_out(w, c, &w->ground, &t[k], up, &r);
            moved = true;
        }
        if (!moved) break;
    }
    return r;
}

static move_result slide(fk_world *w, fk_body *c, const float d[3], const float up[3]) {
    v3_add(c->p, c->p, d);
    return resolve(w, c, up);
}

void fk_world_move(fk_world *w, fk_body *c, const float d[3], float dt) {
    float up[3], g[3], start[3], vertical;
    v3_copy(g, c->own_gravity ? c->gravity : w->gravity);
    if (v3_norm(up, g) > 0) v3_scale(up, up, -1);
    else v3_set(up, 0, 1, 0);
    fk_body_update(c);
    v3_copy(start, c->p);
    vertical = v3_dot(d, up);
    move_result r = slide(w, c, d, up);
    if (!r.grounded && vertical <= 0) { /* stay on the ground over small dips and down slopes */
        float probe[3], before[3];
        v3_copy(before, c->p);
        v3_scale(probe, up, -(c->step > 0.05f ? c->step : 0.05f));
        move_result s = slide(w, c, probe, up);
        if (s.grounded) r.grounded = true;
        else v3_copy(c->p, before);
    }
    c->grounded = r.grounded;
    for (int k = 0; k < 3; k++) c->v[k] = dt > 0 ? (c->p[k] - start[k]) / dt : 0;
}
