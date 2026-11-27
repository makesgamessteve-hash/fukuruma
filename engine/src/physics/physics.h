/* Deterministic rigid-body physics (plan §3.6): spheres, capsules and boxes; a broadphase grid; contacts solved
   with sequential impulses, friction, restitution and warm starting; islands that fall asleep; gravity per body;
   and kinematic capsule characters that walk with steps and slopes. One world per reference frame. Only
   arithmetic and sqrt on floats, in a fixed order, so a step gives the same bits on every platform
   (-ffp-contract=off). Plain C, no allocation during a step after the first steps have sized the buffers. */
#pragma once
#include <stdbool.h>
#include <stdint.h>

enum { FK_SHAPE_SPHERE, FK_SHAPE_CAPSULE, FK_SHAPE_BOX };
enum { FK_BODY_STATIC, FK_BODY_DYNAMIC, FK_BODY_KINEMATIC, FK_BODY_CHARACTER };

typedef struct {
    int type;
    float radius;  /* sphere, capsule */
    float half[3]; /* box: half extents; capsule: half[1] is half the length of its segment along local y */
} fk_shape;

typedef struct {
    uint32_t id; /* stable, never reused */
    int kind;
    fk_shape shape;
    float p[3], q[4], v[3], w[3]; /* position, rotation (x, y, z, w), velocity, angular velocity */
    float inv_mass, inv_inertia[3]; /* local diagonal */
    float friction, restitution;
    float gravity[3];
    bool own_gravity; /* false: the world's gravity */
    int still;        /* steps in a row below the sleep thresholds */
    bool asleep;
    float step, slope_cos, push_mass; /* characters: step height, steepest walkable slope, heaviest body pushed */
    bool grounded;
    float r[9]; /* rotation matrix (columns), from q */
} fk_body;

typedef struct {
    uint32_t a, b, key; /* body ids and the contact's feature key */
    float jn, jt[2];    /* the impulses of the last step, for warm starting */
} fk_cached;

typedef struct {
    uint32_t a, b;
    float point[3], normal[3], impulse;
} fk_impact;

typedef struct fk_world fk_world;

/* Terrain (terrain-streaming spec): a heightfield in the world's frame (y up), (n + 1)^2 heights over n x n cells of
   size cell with its corner at (x0, z0). Static and not part of the bodies or their saved state: it is rebuilt
   deterministically from the world's data. */
typedef struct {
    float x0, z0, cell;
    int n;
    float *h; /* row-major: h[j * (n + 1) + i] at (x0 + i cell, z0 + j cell) */
} fk_terrain;

fk_world *fk_world_create(const float gravity[3]);
void fk_world_destroy(fk_world *w);
void fk_world_gravity(fk_world *w, const float gravity[3]); /* wakes every body */
const float *fk_world_get_gravity(const fk_world *w);
/* Adds a body (kind and shape set by the caller, mass 0 for static and kinematic bodies) and returns its id. */
uint32_t fk_world_add(fk_world *w, const fk_body *init, float mass);
bool fk_world_remove(fk_world *w, uint32_t id);
fk_body *fk_world_body(fk_world *w, uint32_t id); /* NULL when there is no such body */
void fk_world_wake(fk_world *w, fk_body *b);
int fk_world_count(const fk_world *w);
fk_body *fk_world_bodies(fk_world *w); /* in creation order */
/* One step of dt seconds. Returns the new touches of this step with an impulse above min_impulse. */
const fk_impact *fk_world_step(fk_world *w, float dt, float min_impulse, int *count);
/* Moves a character by d (metres), sliding along walls, climbing steps and staying on walkable ground. dt sets
   the velocity it pushes light bodies with. */
void fk_world_move(fk_world *w, fk_body *character, const float d[3], float dt);

/* Saving: everything a step depends on. */
uint32_t fk_world_next_id(const fk_world *w);
const fk_cached *fk_world_cache(const fk_world *w, int *count);
/* Restoring: an empty world, then bodies with their ids and state, then the cache. */
void fk_world_clear(fk_world *w, uint32_t next_id);
bool fk_world_put(fk_world *w, const fk_body *b); /* exactly as saved; false unless ids rise and are below next_id */
void fk_world_put_cache(fk_world *w, const fk_cached *c, int count);
/* Replaces the world's terrain (heights copied; NULL removes it); bodies touching it collide with a static ground
   body of id 0 and the given friction. */
void fk_world_terrain(fk_world *w, float x0, float z0, float cell, int n, const float *heights, float friction);
const fk_terrain *fk_world_get_terrain(const fk_world *w);

/* Narrowphase, for tests and the character: contacts between two bodies (normal from a to b, depth > 0 when
   overlapping), up to 4. */
typedef struct {
    float point[3], normal[3], depth;
    uint32_t key;
} fk_touch;
int fk_collide(const fk_body *a, const fk_body *b, fk_touch out[4]);
void fk_body_update(fk_body *b); /* recomputes r from q */
void fk_body_aabb(const fk_body *b, float lo[3], float hi[3]);

/* Terrain queries: the ground's height and normal under (x, z) (false outside), and a body's contacts with it
   (normals from the ground to the body). */
void fk_terrain_set(fk_terrain *t, float x0, float z0, float cell, int n, const float *heights);
bool fk_terrain_height(const fk_terrain *t, float x, float z, float *height, float normal[3]);
int fk_terrain_collide(const fk_terrain *t, const fk_body *b, fk_touch out[4]);
