/* Water courses (rivers-and-lakes spec): rivers and lakes in a square of a world's ground around the range. The
   ground's heights on a grid are flooded from the square's edges and the sea (priority flood): basins fill to lakes,
   and every point drains along the path the flood reached it by. Where enough ground drains through a point, a river
   runs: its channel is carved into the ground (fk_planet_height subtracts it) and its water stands in the channel.
   Plain C, deterministic, read-only once built. */
#pragma once
#include <stddef.h>
#include <stdint.h>

#include "gfx/gfx.h"

struct fk_planet;

enum { FK_WATER_NONE, FK_WATER_RIVER, FK_WATER_LAKE };

typedef struct fk_hydro {
    double up[3], east[3], north[3]; /* the grid's frame: centred on up, x along east, z along north (metres) */
    double cell;                     /* metres between samples */
    int n;                           /* (n + 1)^2 samples */
    float *carve;                    /* metres the ground is lowered at each sample */
    float *water;                    /* the water surface's height (as fk_planet_height) where kind is not NONE; the
                                        sea floor (below 0) at the sea's samples */
    float *flow;                     /* samples draining through each sample, itself included */
    int32_t *to;                     /* where each sample drains to; -1: out of the square or into the sea */
    uint8_t *kind;                   /* FK_WATER_* */
    uint32_t seed;                   /* the lake basins' and the courses' wiggle */
} fk_hydro;

/* Bytes of memory a grid of n x n cells needs (fk_hydro_build lays the arrays out in it). */
size_t fk_hydro_size(int n);
/* Builds the water courses of planet p (with no hydro attached) in memory of fk_hydro_size(n) bytes. keep: metres
   around up left uncarved (the range's levelled site). Returns the number of river samples. */
int fk_hydro_build(fk_hydro *h, void *memory, const struct fk_planet *p, const double up[3], const double east[3],
                   const double north[3], int n, double cell, double keep);
/* Metres the ground is lowered at unit direction d of a world of radius r (0 outside the grid). */
double fk_hydro_carve(const fk_hydro *h, double radius, const double d[3]);
/* The water surfaces in the range's local frame (x east, y up from the ground at up, z north, following the
   curvature like fk_planet_grid): river ribbons along their courses (white where they fall), lakes as flat quads.
   With vertices NULL, only counts. Returns the number of vertices (indices: the same count). */
int fk_hydro_mesh(const fk_hydro *h, const struct fk_planet *p, fk_vertex *vertices, uint32_t *indices);
