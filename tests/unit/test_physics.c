#include <math.h>
#include <string.h>

#include "core/dmath.h"
#include "core/rng.h"
#include "physics/physics.h"
#include "utest.h"

static const float G[3] = {0, -9.81f, 0};
static const float DT = 1.0f / 60;

static fk_body shape(int kind, int type, float radius, float hx, float hy, float hz, float x, float y, float z) {
    fk_body b;
    memset(&b, 0, sizeof b);
    b.kind = kind, b.shape.type = type, b.shape.radius = radius;
    b.shape.half[0] = hx, b.shape.half[1] = hy, b.shape.half[2] = hz;
    b.p[0] = x, b.p[1] = y, b.p[2] = z;
    b.q[3] = 1;
    b.friction = 0.5f;
    return b;
}

static fk_body box(int kind, float hx, float hy, float hz, float x, float y, float z) {
    return shape(kind, FK_SHAPE_BOX, 0, hx, hy, hz, x, y, z);
}

static fk_body ball(int kind, float r, float x, float y, float z) { return shape(kind, FK_SHAPE_SPHERE, r, 0, 0, 0, x, y, z); }

static fk_world *with_ground(void) {
    fk_world *w = fk_world_create(G);
    fk_body ground = box(FK_BODY_STATIC, 50, 0.5f, 50, 0, -0.5f, 0);
    fk_world_add(w, &ground, 0);
    return w;
}

static void run(fk_world *w, int steps) {
    int n;
    for (int i = 0; i < steps; i++) fk_world_step(w, DT, 1e9f, &n);
}

static void turn(fk_body *b, float ax, float ay, float az, float angle) { /* rotation about a unit axis */
    float s = (float)fk_dsin(angle / 2);
    b->q[0] = ax * s, b->q[1] = ay * s, b->q[2] = az * s, b->q[3] = (float)fk_dcos(angle / 2);
}

UTEST(physics, a_ball_comes_to_rest_and_sleeps) {
    fk_world *w = with_ground();
    fk_body b = ball(FK_BODY_DYNAMIC, 0.5f, 0, 3, 0);
    uint32_t id = fk_world_add(w, &b, 1);
    run(w, 240);
    fk_body *r = fk_world_body(w, id);
    EXPECT_LT(fabsf(r->p[1] - 0.5f), 0.02f);
    EXPECT_TRUE(r->asleep);
    EXPECT_EQ(fk_world_count(w), 2);
    fk_world_destroy(w);
}

UTEST(physics, boxes_stack) {
    fk_world *w = with_ground();
    uint32_t ids[5];
    for (int i = 0; i < 5; i++) {
        fk_body b = box(FK_BODY_DYNAMIC, 0.5f, 0.5f, 0.5f, 0, 0.5f + i * 1.0f, 0);
        ids[i] = fk_world_add(w, &b, 10);
    }
    run(w, 600);
    for (int i = 0; i < 5; i++) {
        fk_body *b = fk_world_body(w, ids[i]);
        EXPECT_LT(fabsf(b->p[0]) + fabsf(b->p[2]), 0.02f);
        EXPECT_LT(fabsf(b->p[1] - (0.5f + i * 1.0f)), 0.05f);
        EXPECT_TRUE(b->asleep);
    }
    fk_world_destroy(w);
}

static float slide_distance(float degrees) {
    fk_world *w = fk_world_create(G);
    float a = degrees * (float)FK_PI / 180;
    fk_body ramp = box(FK_BODY_STATIC, 10, 0.5f, 3, 0, 0, 0);
    turn(&ramp, 0, 0, 1, a);
    fk_world_add(w, &ramp, 0);
    /* a box resting on the ramp's top face, near its middle */
    float nx = -(float)fk_dsin(a), ny = (float)fk_dcos(a);
    fk_body b = box(FK_BODY_DYNAMIC, 0.4f, 0.4f, 0.4f, nx * 0.91f, ny * 0.91f, 0);
    turn(&b, 0, 0, 1, a);
    uint32_t id = fk_world_add(w, &b, 5);
    float start = fk_world_body(w, id)->p[0];
    run(w, 180);
    float moved = fabsf(fk_world_body(w, id)->p[0] - start);
    fk_world_destroy(w);
    return moved;
}

UTEST(physics, friction_holds_and_steep_slopes_slide) {
    EXPECT_LT(slide_distance(15), 0.03f); /* tan 15 deg = 0.27 < 0.5 */
    EXPECT_GT(slide_distance(40), 1.0f);  /* tan 40 deg = 0.84 > 0.5 */
}

UTEST(physics, restitution_bounces) {
    fk_world *w = with_ground();
    fk_body b = ball(FK_BODY_DYNAMIC, 0.25f, 0, 4, 0);
    b.restitution = 0.8f;
    uint32_t id = fk_world_add(w, &b, 1);
    float top = 0;
    bool landed = false;
    int n;
    for (int i = 0; i < 180; i++) {
        const fk_impact *hit = fk_world_step(w, DT, 1, &n);
        if (n) {
            landed = true;
            EXPECT_EQ(hit[0].b, id);
            EXPECT_GT(hit[0].impulse, 1.0f);
            EXPECT_GT(hit[0].normal[1], 0.99f);
        }
        if (landed && fk_world_body(w, id)->p[1] > top) top = fk_world_body(w, id)->p[1];
    }
    EXPECT_TRUE(landed);
    EXPECT_GT(top, 2.0f); /* back up to more than half of the 3.75 m drop */
    fk_world_destroy(w);
}

/* A busy scene: a stack, tumbling boxes, balls and a capsule, from seeded random positions. */
static fk_world *busy(void) {
    fk_world *w = with_ground();
    fk_rng r;
    fk_rng_seed(&r, 7);
    for (int i = 0; i < 4; i++) {
        fk_body b = box(FK_BODY_DYNAMIC, 0.5f, 0.5f, 0.5f, 3, 0.5f + i, 0);
        fk_world_add(w, &b, 10);
    }
    for (int i = 0; i < 12; i++) {
        float x = (float)fk_rng_float(&r) * 6 - 3, z = (float)fk_rng_float(&r) * 6 - 3, y = 2 + i * 0.8f;
        fk_body b = i % 3 == 0 ? ball(FK_BODY_DYNAMIC, 0.3f, x, y, z)
                    : i % 3 == 1 ? box(FK_BODY_DYNAMIC, 0.3f, 0.2f, 0.4f, x, y, z)
                                 : shape(FK_BODY_DYNAMIC, FK_SHAPE_CAPSULE, 0.2f, 0, 0.3f, 0, x, y, z);
        turn(&b, 0.6f, 0.8f, 0, (float)fk_rng_float(&r) * 3);
        b.v[0] = (float)fk_rng_float(&r) * 2 - 1;
        fk_world_add(w, &b, 2);
    }
    return w;
}

static uint64_t world_hash(fk_world *w) {
    uint64_t h = FK_HASH_INIT;
    for (int i = 0; i < fk_world_count(w); i++) {
        const fk_body *b = &fk_world_bodies(w)[i];
        h = fk_hash_bytes(h, b->p, sizeof b->p);
        h = fk_hash_bytes(h, b->q, sizeof b->q);
        h = fk_hash_bytes(h, b->v, sizeof b->v);
        h = fk_hash_bytes(h, b->w, sizeof b->w);
    }
    return h;
}

UTEST(physics, ten_thousand_steps_are_deterministic) {
    fk_world *a = busy(), *b = busy();
    run(a, 10000);
    run(b, 10000);
    uint64_t ha = world_hash(a);
    EXPECT_EQ(ha, world_hash(b));
    /* Recorded once; every platform must reach exactly this state. */
    EXPECT_EQ(ha, 0x7d2bd0294d1006faull);
    fk_world_destroy(a);
    fk_world_destroy(b);
}

UTEST(physics, a_restored_world_continues_identically) {
    fk_world *a = busy();
    run(a, 50);
    fk_world *b = fk_world_create(G);
    fk_world_clear(b, fk_world_next_id(a));
    for (int i = 0; i < fk_world_count(a); i++) ASSERT_TRUE(fk_world_put(b, &fk_world_bodies(a)[i]));
    EXPECT_FALSE(fk_world_put(b, &fk_world_bodies(a)[0])); /* ids must rise */
    int n;
    const fk_cached *cache = fk_world_cache(a, &n);
    EXPECT_GT(n, 0);
    fk_world_put_cache(b, cache, n);
    run(a, 200);
    run(b, 200);
    EXPECT_EQ(world_hash(a), world_hash(b));
    fk_world_destroy(a);
    fk_world_destroy(b);
}

UTEST(physics, removing_a_support_wakes_what_rests_on_it) {
    fk_world *w = with_ground();
    fk_body lower = box(FK_BODY_DYNAMIC, 0.5f, 0.5f, 0.5f, 0, 0.5f, 0), upper = box(FK_BODY_DYNAMIC, 0.5f, 0.5f, 0.5f, 0, 1.5f, 0);
    uint32_t low = fk_world_add(w, &lower, 1), up = fk_world_add(w, &upper, 1);
    run(w, 300);
    EXPECT_TRUE(fk_world_body(w, up)->asleep);
    EXPECT_TRUE(fk_world_remove(w, low));
    EXPECT_FALSE(fk_world_remove(w, low));
    EXPECT_TRUE(fk_world_body(w, low) == NULL);
    run(w, 120);
    EXPECT_LT(fabsf(fk_world_body(w, up)->p[1] - 0.5f), 0.03f);
    fk_body again = ball(FK_BODY_DYNAMIC, 0.1f, 5, 5, 5);
    EXPECT_GT(fk_world_add(w, &again, 1), up); /* ids are never reused */
    fk_world_destroy(w);
}

UTEST(physics, kinematic_bodies_push_and_wake) {
    fk_world *w = with_ground();
    fk_body crate = box(FK_BODY_DYNAMIC, 0.5f, 0.5f, 0.5f, 0, 0.5f, 0);
    uint32_t c = fk_world_add(w, &crate, 1);
    run(w, 120);
    EXPECT_TRUE(fk_world_body(w, c)->asleep);
    fk_body pusher = box(FK_BODY_KINEMATIC, 0.5f, 0.5f, 0.5f, -1.2f, 0.5f, 0);
    pusher.v[0] = 1;
    uint32_t k = fk_world_add(w, &pusher, 0);
    run(w, 120);
    EXPECT_GT(fk_world_body(w, k)->p[0], 0.7f);
    EXPECT_GT(fk_world_body(w, c)->p[0], 0.5f);
    fk_world_step(w, 0, 0, &(int){0}); /* no time: nothing happens */
    fk_world_destroy(w);
}

UTEST(physics, own_gravity) {
    fk_world *w = fk_world_create(G);
    fk_body b = ball(FK_BODY_DYNAMIC, 0.5f, 0, 0, 0);
    b.own_gravity = true, b.gravity[0] = 2;
    uint32_t id = fk_world_add(w, &b, 1);
    fk_body plain = ball(FK_BODY_DYNAMIC, 0.5f, 10, 0, 0);
    uint32_t p = fk_world_add(w, &plain, 1);
    run(w, 60);
    EXPECT_GT(fk_world_body(w, id)->p[0], 0.9f);
    EXPECT_LT(fk_world_body(w, p)->p[1], -4.0f);
    float none[3] = {0, 0, 0};
    fk_world_gravity(w, none);
    float y = fk_world_body(w, p)->p[1], vy = fk_world_body(w, p)->v[1];
    run(w, 60);
    EXPECT_LT(fabsf(fk_world_body(w, p)->p[1] - (y + vy)), 0.01f);
    fk_world_destroy(w);
}

/* Narrowphase ------------------------------------------------------------------------------------------- */

static int touches(fk_body a, fk_body b, fk_touch t[4]) {
    fk_body_update(&a);
    fk_body_update(&b);
    return fk_collide(&a, &b, t);
}

UTEST(collide, spheres_and_capsules) {
    fk_touch t[4];
    EXPECT_EQ(touches(ball(0, 1, 0, 0, 0), ball(0, 1, 1.5f, 0, 0), t), 1);
    EXPECT_NEAR(t[0].depth, 0.5f, 1e-5f);
    EXPECT_NEAR(t[0].normal[0], 1, 1e-6f);
    EXPECT_EQ(touches(ball(0, 1, 0, 0, 0), ball(0, 1, 2.5f, 0, 0), t), 0);
    EXPECT_EQ(touches(ball(0, 1, 0, 0, 0), ball(0, 1, 0, 0, 0), t), 1); /* same centre: pushed along +y */
    EXPECT_NEAR(t[0].normal[1], 1, 1e-6f);
    fk_body cap = shape(0, FK_SHAPE_CAPSULE, 0.5f, 0, 1, 0, 0, 0, 0);
    EXPECT_EQ(touches(ball(0, 0.5f, 0.8f, 0.9f, 0), cap, t), 1); /* beside the segment */
    EXPECT_NEAR(t[0].normal[0], -1, 1e-5f);
    EXPECT_EQ(touches(cap, ball(0, 0.5f, 0, 1.9f, 0), t), 1); /* over its top end */
    EXPECT_NEAR(t[0].normal[1], 1, 1e-5f);
    fk_body lying = shape(0, FK_SHAPE_CAPSULE, 0.5f, 0, 1, 0, 0.9f, 0, 0);
    turn(&lying, 1, 0, 0, (float)FK_PI / 2);
    EXPECT_EQ(touches(cap, lying, t), 1);
    EXPECT_NEAR(t[0].depth, 0.1f, 1e-4f);
    fk_body parallel = shape(0, FK_SHAPE_CAPSULE, 0.5f, 0, 1, 0, 0.9f, 0.5f, 0);
    EXPECT_EQ(touches(cap, parallel, t), 1);
    fk_body dot = shape(0, FK_SHAPE_CAPSULE, 0.5f, 0, 0, 0, 0.9f, 0, 0); /* a capsule with no length */
    EXPECT_EQ(touches(dot, shape(0, FK_SHAPE_CAPSULE, 0.5f, 0, 0, 0, 0, 0, 0), t), 1);
    EXPECT_EQ(touches(dot, cap, t), 1);
    EXPECT_EQ(touches(cap, dot, t), 1);
}

UTEST(collide, spheres_and_capsules_with_boxes) {
    fk_touch t[4];
    fk_body b = box(0, 1, 1, 1, 0, 0, 0);
    EXPECT_EQ(touches(ball(0, 0.5f, 0, 1.3f, 0), b, t), 1);
    EXPECT_NEAR(t[0].normal[1], -1, 1e-6f); /* from the ball to the box */
    EXPECT_NEAR(t[0].depth, 0.2f, 1e-5f);
    EXPECT_EQ(touches(b, ball(0, 0.5f, 0.2f, 0.9f, 0), t), 1); /* centre inside: out through the top */
    EXPECT_NEAR(t[0].normal[1], 1, 1e-6f);
    EXPECT_NEAR(t[0].depth, 0.6f, 1e-5f);
    EXPECT_EQ(touches(b, ball(0, 0.5f, 3, 0, 0), t), 0);
    fk_body standing = shape(0, FK_SHAPE_CAPSULE, 0.4f, 0, 0.8f, 0, 0, 2.1f, 0);
    EXPECT_EQ(touches(b, standing, t), 1); /* on its bottom end */
    EXPECT_EQ(t[0].key, 1u);
    fk_body lying = shape(0, FK_SHAPE_CAPSULE, 0.4f, 0, 0.8f, 0, 0, 1.3f, 0);
    turn(&lying, 0, 0, 1, (float)FK_PI / 2);
    EXPECT_EQ(touches(lying, b, t), 2); /* both ends */
    fk_body across = shape(0, FK_SHAPE_CAPSULE, 0.4f, 0, 3, 0, 0, 1.3f, 0); /* ends far out, middle over the box */
    turn(&across, 0, 0, 1, (float)FK_PI / 2);
    EXPECT_EQ(touches(b, across, t), 1);
    EXPECT_EQ(t[0].key, 3u);
    EXPECT_NEAR(t[0].normal[1], 1, 1e-4f);
    EXPECT_EQ(touches(b, shape(0, FK_SHAPE_CAPSULE, 0.4f, 0, 3, 0, 0, 5, 0), t), 0);
}

UTEST(collide, boxes) {
    fk_touch t[4];
    fk_body a = box(0, 1, 1, 1, 0, 0, 0);
    EXPECT_EQ(touches(a, box(0, 1, 1, 1, 0.2f, 1.9f, 0.1f), t), 4); /* face on face */
    for (int i = 0; i < 4; i++) {
        EXPECT_NEAR(t[i].depth, 0.1f, 1e-4f);
        EXPECT_NEAR(t[i].normal[1], 1, 1e-5f);
    }
    EXPECT_EQ(touches(box(0, 1, 1, 1, 0.2f, 1.9f, 0.1f), a, t), 4); /* the other way round: normals flip */
    EXPECT_NEAR(t[0].normal[1], -1, 1e-5f);
    fk_body twisted = box(0, 1, 0.5f, 1, 0, 1.4f, 0); /* turned 45 degrees: an octagon, kept to four points */
    turn(&twisted, 0, 1, 0, (float)FK_PI / 4);
    EXPECT_EQ(touches(a, twisted, t), 4);
    fk_body small = box(0, 0.3f, 0.3f, 0.3f, 0, 0, 1.2f); /* B's face is the reference: it is clearly better */
    turn(&small, 1, 0, 0, 0.3f);
    EXPECT_GE(touches(small, box(0, 2, 2, 2, 0, 0, 3.4f), t), 1);
    /* Edge against edge: a box turned 45 degrees about x (its top is an edge along x) under a bar turned 45 degrees
       about its own long axis and laid along z (its bottom is an edge along z). */
    fk_body tilted = box(0, 1, 1, 1, 0, 0, 0);
    turn(&tilted, 1, 0, 0, (float)FK_PI / 4);
    fk_body crossed = box(0, 2, 0.2f, 0.2f, 0, 1.414214f + 0.282843f - 0.02f, 0);
    const float s45 = 0.38268343f, c45 = 0.92387953f, h = 0.70710678f; /* q_y(90) * q_x(45) */
    crossed.q[0] = h * s45, crossed.q[1] = h * c45, crossed.q[2] = -h * s45, crossed.q[3] = h * c45;
    EXPECT_EQ(touches(tilted, crossed, t), 1);
    EXPECT_NEAR(t[0].depth, 0.02f, 2e-3f);
    EXPECT_GE(t[0].key >> 24, 6u);
    EXPECT_EQ(touches(a, box(0, 1, 1, 1, 0, 2.1f, 0), t), 0);
    EXPECT_EQ(touches(a, box(0, 1, 1, 1, 2.1f, 0, 0), t), 0);
    fk_body far_edge = box(0, 1, 1, 1, 2.6f, 2.6f, 0);
    turn(&far_edge, 0.70710678f, 0, 0.70710678f, 0.9f);
    EXPECT_EQ(touches(a, far_edge, t), 0);
    float lo[3], hi[3];
    fk_body_update(&twisted);
    fk_body_aabb(&twisted, lo, hi);
    EXPECT_NEAR(hi[0], 1.41421f, 1e-4f);
}

/* Characters ----------------------------------------------------------------------------------------- */

static fk_body *character(fk_world *w, float x, float z) {
    fk_body c = shape(FK_BODY_CHARACTER, FK_SHAPE_CAPSULE, 0.4f, 0, 0.5f, 0, x, 0.9f, z);
    c.step = 0.4f, c.slope_cos = 0.64f, c.push_mass = 50;
    return fk_world_body(w, fk_world_add(w, &c, 0));
}

static void walk(fk_world *w, uint32_t id, float dx, float dz, int steps) {
    for (int i = 0; i < steps; i++) {
        const float d[3] = {dx, -0.05f, dz};
        fk_world_move(w, fk_world_body(w, id), d, DT);
        fk_world_step(w, DT, 1e9f, &(int){0});
    }
}

UTEST(character, walks_on_ground_and_slides_along_walls) {
    fk_world *w = with_ground();
    fk_body wall = box(FK_BODY_STATIC, 0.5f, 2, 5, 3, 2, 0);
    fk_world_add(w, &wall, 0);
    uint32_t id = character(w, 0, 0)->id;
    walk(w, id, 0.05f, 0.05f, 60); /* diagonally into the wall */
    fk_body *c = fk_world_body(w, id);
    EXPECT_TRUE(c->grounded);
    EXPECT_NEAR(c->p[1], 0.9f, 0.01f);
    EXPECT_LT(c->p[0], 2.11f);
    EXPECT_GT(c->p[2], 2.5f); /* kept going along the wall */
    fk_world_destroy(w);
}

UTEST(character, climbs_steps_but_not_walls) {
    fk_world *w = with_ground();
    fk_body low = box(FK_BODY_STATIC, 1, 0.15f, 3, 2, 0.15f, 0), high = box(FK_BODY_STATIC, 1, 0.35f, 3, 2, 0.35f, 6);
    fk_world_add(w, &low, 0);
    fk_world_add(w, &high, 0);
    uint32_t a = character(w, 0, 0)->id, b = character(w, 0, 6)->id;
    walk(w, a, 0.05f, 0, 50);
    walk(w, b, 0.05f, 0, 50);
    EXPECT_NEAR(fk_world_body(w, a)->p[1], 1.2f, 0.02f); /* on the 0.3 m step */
    EXPECT_GT(fk_world_body(w, a)->p[0], 2.0f);
    EXPECT_LT(fk_world_body(w, b)->p[0], 0.65f); /* 0.7 m is too high */
    walk(w, a, 0.05f, 0, 40);                     /* off the far side: down onto the ground */
    EXPECT_NEAR(fk_world_body(w, a)->p[1], 0.9f, 0.02f);
    EXPECT_TRUE(fk_world_body(w, a)->grounded);
    fk_world_destroy(w);
}

static float climb(float degrees) {
    fk_world *w = with_ground();
    float a = degrees * (float)FK_PI / 180;
    /* a ramp whose top face comes out of the ground at x = 1 */
    fk_body ramp = box(FK_BODY_STATIC, 6, 0.5f, 3, 1 + 6 * (float)fk_dcos(a) + 0.5f * (float)fk_dsin(a),
                       6 * (float)fk_dsin(a) - 0.5f * (float)fk_dcos(a), 0);
    turn(&ramp, 0, 0, 1, a);
    fk_world_add(w, &ramp, 0);
    uint32_t id = character(w, 0, 0)->id;
    walk(w, id, 0.05f, 0, 90);
    float y = fk_world_body(w, id)->p[1];
    fk_world_destroy(w);
    return y;
}

UTEST(character, walkable_slopes_only) {
    EXPECT_GT(climb(25), 1.5f); /* up a 25 degree ramp */
    EXPECT_LT(climb(65), 1.3f); /* not up a 65 degree one */
}

UTEST(character, pushes_light_bodies_and_stops_at_heavy_ones) {
    fk_world *w = with_ground();
    fk_body light = box(FK_BODY_DYNAMIC, 0.4f, 0.4f, 0.4f, 1.5f, 0.4f, 0), heavy = box(FK_BODY_DYNAMIC, 0.4f, 0.4f, 0.4f, 1.5f, 0.4f, 5);
    uint32_t l = fk_world_add(w, &light, 20), h = fk_world_add(w, &heavy, 500);
    uint32_t a = character(w, 0, 0)->id, b = character(w, 0, 5)->id;
    walk(w, a, 0.04f, 0, 90);
    walk(w, b, 0.04f, 0, 90);
    EXPECT_GT(fk_world_body(w, l)->p[0], 2.5f);
    EXPECT_LT(fabsf(fk_world_body(w, h)->p[0] - 1.5f), 0.05f);
    EXPECT_LT(fk_world_body(w, b)->p[0], 0.75f);
    float d[3] = {0, 0, 0};
    fk_world_move(w, fk_world_body(w, a), d, 0); /* no time: no velocity */
    EXPECT_EQ(fk_world_body(w, a)->v[0], 0.0f);
    fk_world_destroy(w);
}

UTEST(character, falls_and_lands_with_its_own_gravity) {
    float none[3] = {0, 0, 0};
    fk_world *w = fk_world_create(none);
    fk_body ground = box(FK_BODY_STATIC, 5, 0.5f, 5, 0, -0.5f, 0);
    fk_world_add(w, &ground, 0);
    fk_body *c = character(w, 0, 0);
    c->p[1] = 3;
    c->own_gravity = true, c->gravity[1] = -9.81f;
    uint32_t id = c->id;
    for (int i = 0; i < 60; i++) {
        const float d[3] = {0, -0.1f, 0};
        fk_world_move(w, fk_world_body(w, id), d, DT);
    }
    EXPECT_NEAR(fk_world_body(w, id)->p[1], 0.9f, 0.01f);
    EXPECT_TRUE(fk_world_body(w, id)->grounded);
    fk_body *loose = character(w, 20, 0); /* no ground below, no gravity: nothing to stand on */
    loose->step = 0;
    const float d[3] = {0.1f, 0, 0};
    fk_world_move(w, loose, d, DT);
    EXPECT_FALSE(loose->grounded);
    fk_world_destroy(w);
}

/* Terrain ------------------------------------------------------------------------------------------- */

/* A 16 x 16 cell heightfield (1 m cells, corner at -8, -8): flat at 0 for x < 0, rising 0.5 m per metre beyond. */
static fk_world *with_terrain(void) {
    fk_world *w = fk_world_create(G);
    float h[17 * 17];
    for (int j = 0; j <= 16; j++)
        for (int i = 0; i <= 16; i++) h[j * 17 + i] = i > 8 ? 0.5f * (float)(i - 8) : 0;
    fk_world_terrain(w, -8, -8, 1, 16, h, 0.9f);
    return w;
}

UTEST(terrain, heights_normals_and_edges) {
    fk_world *w = with_terrain();
    const fk_terrain *t = fk_world_get_terrain(w);
    float h, n[3];
    ASSERT_TRUE(fk_terrain_height(t, -3, 2, &h, n));
    EXPECT_NEAR(h, 0, 1e-6f);
    EXPECT_NEAR(n[1], 1, 1e-6f);
    ASSERT_TRUE(fk_terrain_height(t, 2.25f, 0.5f, &h, n)); /* the lower triangle of its cell */
    EXPECT_NEAR(h, 1.125f, 1e-5f);
    EXPECT_LT(n[0], -0.4f);
    ASSERT_TRUE(fk_terrain_height(t, 2.75f, 0.75f, &h, n)); /* the upper one */
    EXPECT_NEAR(h, 1.375f, 1e-5f);
    EXPECT_TRUE(fk_terrain_height(t, 8, 8, &h, NULL)); /* the far corner belongs to the last cell */
    EXPECT_NEAR(h, 4, 1e-5f);
    EXPECT_FALSE(fk_terrain_height(t, 9, 0, &h, n));
    EXPECT_FALSE(fk_terrain_height(t, 0, -9, &h, n));
    fk_world_terrain(w, 0, 0, 1, 0, NULL, 0.5f); /* removed */
    EXPECT_FALSE(fk_terrain_height(fk_world_get_terrain(w), 0, 0, &h, n));
    fk_body b = ball(FK_BODY_DYNAMIC, 0.5f, 0, 0, 0);
    fk_body_update(&b);
    fk_touch touch[4];
    EXPECT_EQ(fk_terrain_collide(fk_world_get_terrain(w), &b, touch), 0);
    fk_world_destroy(w);
}

UTEST(terrain, bodies_rest_on_it) {
    fk_world *w = with_terrain();
    fk_body s = ball(FK_BODY_DYNAMIC, 0.5f, -4, 2, 0);
    fk_body c = shape(FK_BODY_DYNAMIC, FK_SHAPE_CAPSULE, 0.3f, 0, 0.5f, 0, -2, 2, 3);
    turn(&c, 0, 0, 1, 1.5707963f); /* lying down */
    fk_body b = box(FK_BODY_DYNAMIC, 0.5f, 0.5f, 0.5f, -5, 3, -4);
    turn(&b, 1, 0, 0, 0.3f);
    uint32_t ids[3] = {fk_world_add(w, &s, 1), fk_world_add(w, &c, 1), fk_world_add(w, &b, 1)};
    run(w, 300);
    EXPECT_NEAR(fk_world_body(w, ids[0])->p[1], 0.5f, 0.03f);
    EXPECT_NEAR(fk_world_body(w, ids[1])->p[1], 0.3f, 0.03f);
    EXPECT_NEAR(fk_world_body(w, ids[2])->p[1], 0.5f, 0.03f);
    for (int i = 0; i < 3; i++) EXPECT_TRUE(fk_world_body(w, ids[i])->asleep);
    fk_body r = ball(FK_BODY_DYNAMIC, 0.5f, 3, 6, 0); /* onto the slope: friction holds a gentle one */
    uint32_t on_slope = fk_world_add(w, &r, 1);
    run(w, 120);
    float h;
    fk_terrain_height(fk_world_get_terrain(w), fk_world_body(w, on_slope)->p[0], 0, &h, NULL);
    EXPECT_GT(fk_world_body(w, on_slope)->p[1], h);
    fk_world_destroy(w);
}

UTEST(terrain, characters_walk_up_it) {
    fk_world *w = with_terrain();
    uint32_t id = character(w, -4, 0)->id;
    walk(w, id, 0.05f, 0, 160); /* 8 m: up the slope (27 degrees, walkable) */
    fk_body *c = fk_world_body(w, id);
    float h;
    ASSERT_TRUE(fk_terrain_height(fk_world_get_terrain(w), c->p[0], c->p[2], &h, NULL));
    EXPECT_TRUE(c->grounded);
    EXPECT_GT(c->p[0], 3.5f);
    EXPECT_GT(c->p[1], h + 0.5f);
    EXPECT_LT(c->p[1], h + 1.6f);
    fk_world_destroy(w);
}

UTEST(terrain, steep_terrain_is_a_wall) {
    fk_world *w = fk_world_create(G);
    float h[9 * 9];
    for (int j = 0; j <= 8; j++)
        for (int i = 0; i <= 8; i++) h[j * 9 + i] = i > 4 ? 3.0f * (float)(i - 4) : 0; /* 72 degrees */
    fk_world_terrain(w, -4, -4, 1, 8, h, 0.8f);
    uint32_t id = character(w, -2, 0)->id;
    walk(w, id, 0.05f, 0, 120);
    EXPECT_LT(fk_world_body(w, id)->p[0], 0.8f);
    fk_world_destroy(w);
}

/* Digs ------------------------------------------------------------------------------------------------ */

UTEST(terrain, digs_open_pits_and_tunnels) {
    fk_world *w = fk_world_create(G);
    float h[17 * 17];
    for (int i = 0; i < 17 * 17; i++) h[i] = 0;
    fk_world_terrain(w, -8, -8, 1, 16, h, 0.9f);
    const float digs[8] = {0, -1.5f, 0, 2.5f, 3, -2.5f, 0, 2.5f}; /* a pit and, overlapping it, a deeper hole */
    fk_world_digs(w, digs, 2, true);
    const fk_terrain *t = fk_world_get_terrain(w);
    EXPECT_GT(fk_terrain_solid(t, (float[3]){0, 0.5f, 0}), 0.6f); /* over the opening: no ground at its old level */
    EXPECT_NEAR(fk_terrain_solid(t, (float[3]){6, 0.5f, 0}), 0.5f, 1e-4f); /* away from the digs: the ground */
    EXPECT_LT(fk_terrain_solid(t, (float[3]){-6, -1, 0}), 0);              /* inside the solid */
    EXPECT_GT(fk_terrain_solid(t, (float[3]){1.5f, -2.5f, 0}), 0.9f);      /* where the holes overlap: open */
    fk_body b = ball(FK_BODY_DYNAMIC, 0.5f, 0, 1, 0);
    uint32_t id = fk_world_add(w, &b, 1);
    run(w, 300);
    EXPECT_LT(fk_world_body(w, id)->p[1], -3.0f); /* fell into the pit and rests on its floor */
    EXPECT_GT(fk_world_body(w, id)->p[1], -4.6f);
    uint32_t c = character(w, -5, 0)->id;
    walk(w, c, 0.04f, 0, 260); /* into the pit and on into the deeper hole */
    fk_body *ch = fk_world_body(w, c);
    EXPECT_GT(ch->p[0], 2.0f);
    EXPECT_LT(ch->p[1], -2.5f);
    fk_world_digs(w, NULL, 0, false);
    EXPECT_EQ(fk_world_get_terrain(w)->ndigs, 0);
    fk_world_destroy(w);
}
