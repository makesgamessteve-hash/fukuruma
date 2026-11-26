#include "fx/particles.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "core/rng.h"

#define FK_MAX_PARTICLES 65536

static fk_particle *list;
static int count, budget = 4096;
static fk_rng rng;

void fk_particles_reset(void) {
    count = 0;
    fk_rng_seed(&rng, 0x5041525449434c45ull); /* presentation has its own stream, never the simulation's */
    if (!list) list = malloc(FK_MAX_PARTICLES * sizeof *list);
    if (!list) abort(); /* out of memory at start-up: nothing sensible to continue with */
}

void fk_particles_budget(int max) { budget = max < 0 ? 0 : max > FK_MAX_PARTICLES ? FK_MAX_PARTICLES : max; }

static float uniform(float lo, float hi) { return lo + (hi - lo) * (float)fk_rng_float(&rng); }

/* Two unit vectors perpendicular to d (unit) and to each other. */
static void basis(const float d[3], float u[3], float v[3]) {
    float a[3] = {fabsf(d[0]) < 0.9f ? 1.0f : 0.0f, fabsf(d[0]) < 0.9f ? 0.0f : 1.0f, 0};
    u[0] = d[1] * a[2] - d[2] * a[1], u[1] = d[2] * a[0] - d[0] * a[2], u[2] = d[0] * a[1] - d[1] * a[0];
    float len = sqrtf(u[0] * u[0] + u[1] * u[1] + u[2] * u[2]);
    for (int k = 0; k < 3; k++) u[k] /= len;
    v[0] = d[1] * u[2] - d[2] * u[1], v[1] = d[2] * u[0] - d[0] * u[2], v[2] = d[0] * u[1] - d[1] * u[0];
}

void fk_particles_emit(const fk_emitter *e) {
    if (!list) fk_particles_reset();
    float d[3], u[3], v[3], len = sqrtf(e->direction[0] * e->direction[0] + e->direction[1] * e->direction[1] + e->direction[2] * e->direction[2]);
    for (int k = 0; k < 3; k++) d[k] = len > 0 ? e->direction[k] / len : (k == 1);
    basis(d, u, v);
    for (int i = 0; i < e->count && budget > 0; i++) {
        if (count == budget) { /* full: the oldest particle (the front of the list) makes room */
            memmove(list, list + 1, (size_t)(count - 1) * sizeof *list);
            count--;
        }
        fk_particle *p = &list[count++];
        float a = uniform(0, 6.2831853f), b = e->ring ? 1.5707963f : acosf(1 - uniform(0, 1) * (1 - cosf(e->spread)));
        float s = sinf(b), c = cosf(b), speed = uniform(e->speed_min, e->speed_max), r = e->radius * cbrtf(uniform(0, 1));
        float a2 = uniform(0, 6.2831853f), z = uniform(-1, 1), rz = sqrtf(1 - z * z);
        for (int k = 0; k < 3; k++) {
            float dir = d[k] * c + (u[k] * cosf(a) + v[k] * sinf(a)) * s;
            p->velocity[k] = dir * speed;
            p->position[k] = e->position[k] + r * (k == 0 ? rz * cosf(a2) : k == 1 ? rz * sinf(a2) : z);
        }
        memcpy(p->color, e->color, sizeof p->color);
        memcpy(p->color_end, e->color_end, sizeof p->color_end);
        p->size = e->size, p->size_end = e->size_end;
        p->life = uniform(e->life_min, e->life_max), p->age = 0;
        p->gravity = e->gravity, p->drag = e->drag;
        p->glow = e->glow;
    }
}

void fk_particles_update(float dt) {
    int kept = 0;
    for (int i = 0; i < count; i++) {
        fk_particle p = list[i];
        p.age += dt;
        if (p.age >= p.life) continue;
        float keep = 1 / (1 + p.drag * dt);
        p.velocity[1] -= p.gravity * dt;
        for (int k = 0; k < 3; k++) {
            p.velocity[k] *= keep;
            p.position[k] += p.velocity[k] * dt;
        }
        list[kept++] = p;
    }
    count = kept;
}

int fk_particles_count(void) { return count; }
const fk_particle *fk_particles_list(void) { return list; }
