/* Presentation particles (dust, sparks, scan rings): simulated on the CPU, drawn by the pipeline's forward
   pass. They never affect the simulation. Plain C. */
#pragma once
#include <stdbool.h>

typedef struct {
    float position[3], velocity[3];
    float color[4], color_end[4]; /* linear RGB (glow: times intensity) and alpha, at birth and at death */
    float size, size_end;         /* diameter in metres */
    float life, age;              /* seconds */
    float gravity, drag;          /* m/s^2 downwards; velocity loss per second */
    float stretch;                /* seconds of motion drawn: a streak along the velocity (rain) */
    bool glow;                    /* added light, unlit (sparks, scans); otherwise lit and alpha-blended (dust) */
} fk_particle;

typedef struct {
    int count;
    float position[3], radius;    /* births are spread over a sphere of this radius */
    float direction[3], spread;   /* velocity within this cone (half angle, radians) around direction */
    bool ring;                    /* velocities in the plane across direction instead (rings, shockwaves) */
    float speed_min, speed_max, life_min, life_max;
    float size, size_end, gravity, drag, stretch;
    float color[4], color_end[4];
    bool glow;
} fk_emitter;

void fk_particles_reset(void);       /* no particles; the random stream starts again */
void fk_particles_budget(int max);   /* the most particles alive at once; older ones make room for new ones */
void fk_particles_emit(const fk_emitter *e);
void fk_particles_update(float dt);
int fk_particles_count(void);
void fk_particles_shift(float dx, float dy, float dz); /* every live particle moved (the floating origin moved) */
const fk_particle *fk_particles_list(void);
