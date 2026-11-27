/* Noise graphs (plan 3.8): a planet's terrain recipe as a graph of nodes (sources, combiners, warps, curves),
   described in Lua and compiled here into a flat array evaluated in tight loops. Deterministic: integer hashing and
   double arithmetic only. A compiled graph is read-only, so jobs on several threads may evaluate it at once. */
#pragma once
#include <stddef.h>
#include <stdint.h>

enum {
    FK_N_CONST,   /* p[0] */
    FK_N_PERLIN,  /* gradient noise, about -1..1: p[0] frequency */
    FK_N_FBM,     /* fractal sum of gradient noise: p[0] frequency, p[1] lacunarity, p[2] gain, octaves */
    FK_N_RIDGED,  /* ridged multifractal, 0..1: as fbm */
    FK_N_BILLOW,  /* |noise| fractal, about -1..1: as fbm */
    FK_N_CELLS,   /* Worley cells: p[0] frequency; F1 distance (0..~1), or F2 - F1 when p[1] = 1 (plate edges) */
    FK_N_CRATERS, /* crater field, about -1..0.3: p[0] frequency, p[1] density (0..1) */
    FK_N_WARP,    /* in[0] evaluated at the point moved by in[1] (three offset samples) times p[0] */
    FK_N_ADD, FK_N_SUB, FK_N_MUL, FK_N_MIN, FK_N_MAX, /* in[0], in[1] */
    FK_N_BLEND,   /* in[0] + (in[1] - in[0]) * clamp(in[2], 0, 1) */
    FK_N_SCALE,   /* in[0] * p[0] + p[1] */
    FK_N_CLAMP,   /* in[0] between p[0] and p[1] */
    FK_N_ABS,     /* |in[0]| */
    FK_N_TERRACE, /* in[0] in p[0] steps, softened by p[1] (0 hard .. 1 smooth) */
    FK_N_SMOOTH,  /* smoothstep(p[0], p[1], in[0]) */
    FK_N_POWER,   /* sign(x) |x|^p[0] (deterministic pow) */
    FK_N_LATITUDE,/* the y of the point (the sphere's pole axis) */
    FK_N_COUNT
};

typedef struct {
    int op;
    int in[3];     /* indices of earlier nodes, -1 when unused */
    double p[3];
    int octaves;
    uint64_t seed;
} fk_noise_node;

#define FK_NOISE_MAX_NODES 256

typedef struct fk_noise {
    fk_noise_node nodes[FK_NOISE_MAX_NODES];
    int count; /* the last node is the output */
} fk_noise;

/* Checks a graph: every input names an earlier node, parameters are in range. NULL when it is fine, else why. */
const char *fk_noise_check(const fk_noise *g);
double fk_noise_eval(const fk_noise *g, double x, double y, double z);
/* Gradient noise at a point for a seed, about -1..1 (the source the other nodes build on). */
double fk_perlin(uint64_t seed, double x, double y, double z);
