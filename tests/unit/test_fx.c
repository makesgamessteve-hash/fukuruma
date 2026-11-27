#include <math.h>
#include <string.h>

#include "fx/particles.h"
#include "platform/platform.h"
#include "utest.h"

static fk_emitter burst(int count) {
    fk_emitter e;
    memset(&e, 0, sizeof e);
    e.count = count;
    e.direction[1] = 1;
    e.spread = 0.3f;
    e.speed_min = e.speed_max = 2;
    e.life_min = e.life_max = 1;
    e.size = e.size_end = 0.5f;
    for (int k = 0; k < 4; k++) e.color[k] = e.color_end[k] = 1;
    return e;
}

UTEST(particles, cone_ring_and_motion) {
    fk_particles_reset();
    fk_particles_budget(4096);
    fk_emitter e = burst(200);
    e.position[0] = 5;
    e.radius = 1;
    fk_particles_emit(&e);
    ASSERT_EQ(fk_particles_count(), 200);
    const fk_particle *p = fk_particles_list();
    for (int i = 0; i < 200; i++) {
        float speed = sqrtf(p[i].velocity[0] * p[i].velocity[0] + p[i].velocity[1] * p[i].velocity[1] + p[i].velocity[2] * p[i].velocity[2]);
        EXPECT_NEAR(speed, 2.0f, 1e-4);
        EXPECT_GE(p[i].velocity[1] / speed, cosf(0.3f) - 1e-4f); /* within the cone around +y */
        float dx = p[i].position[0] - 5, d = sqrtf(dx * dx + p[i].position[1] * p[i].position[1] + p[i].position[2] * p[i].position[2]);
        EXPECT_LE(d, 1.0f + 1e-5f); /* born inside the sphere */
    }
    fk_particles_reset();
    e = burst(50);
    e.ring = true;
    e.direction[0] = 1, e.direction[1] = 0; /* a ring across x: velocities in the y-z plane */
    fk_particles_emit(&e);
    for (int i = 0; i < 50; i++) EXPECT_NEAR(fk_particles_list()[i].velocity[0], 0.0f, 1e-5);
    fk_particles_reset();
    e = burst(1);
    e.direction[1] = 0; /* no direction: up */
    e.gravity = 2;
    e.drag = 1;
    fk_particles_emit(&e);
    fk_particles_update(0.5f);
    ASSERT_EQ(fk_particles_count(), 1);
    EXPECT_LT(fk_particles_list()[0].velocity[1], 2.0f); /* gravity and drag slow it */
    EXPECT_GT(fk_particles_list()[0].position[1], 0.0f);
    fk_particles_update(0.6f);
    EXPECT_EQ(fk_particles_count(), 0); /* its life is over */
}

UTEST(particles, budget_and_determinism) {
    fk_particles_reset();
    fk_particles_budget(10);
    fk_emitter e = burst(4);
    fk_particles_emit(&e);
    float first = fk_particles_list()[0].velocity[0];
    e.life_min = e.life_max = 3; /* the newer burst lives longer */
    e.count = 8;
    fk_particles_emit(&e);
    EXPECT_EQ(fk_particles_count(), 10); /* the two oldest made room */
    EXPECT_NEAR(fk_particles_list()[1].life, 1.0f, 1e-6);
    EXPECT_NEAR(fk_particles_list()[2].life, 3.0f, 1e-6);
    fk_particles_reset(); /* the random stream starts again: the same particles */
    fk_particles_budget(10);
    e = burst(4);
    fk_particles_emit(&e);
    EXPECT_EQ(fk_particles_list()[0].velocity[0], first);
    fk_particles_budget(-5);
    fk_particles_emit(&e);
    EXPECT_EQ(fk_particles_count(), 4); /* a zero budget emits nothing */
    fk_particles_budget(1 << 20);       /* clamped */
    fk_particles_budget(4096);
    fk_input_rumble(0.5f, 0.5f, 10); /* no gamepads in tests: nothing happens */
}

UTEST(particles, move_with_the_floating_origin) {
    fk_particles_reset();
    fk_particles_budget(64);
    fk_emitter e = burst(3);
    fk_particles_emit(&e);
    float x = fk_particles_list()[0].position[0], y = fk_particles_list()[0].position[1];
    fk_particles_shift(-4096, 10, 0);
    EXPECT_NEAR(fk_particles_list()[0].position[0], x - 4096, 1e-3f);
    EXPECT_NEAR(fk_particles_list()[0].position[1], y + 10, 1e-3f);
}
