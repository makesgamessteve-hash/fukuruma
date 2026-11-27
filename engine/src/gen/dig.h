/* Dug ground (voxel-terrain spec): see dig.c. */
#pragma once
#include "gen/planet.h"

#define FK_DIG_MAX_N 24 /* lattice cells along a mesh region's edge */

typedef struct {
    const fk_planet *planet;
    double up[3], east[3], north[3]; /* the range's local frame on the planet (unit, planet axes) */
    double base;                     /* the planet's radius plus the ground's height at the frame's origin */
    const float *digs;               /* x, y, z, radius per dig (local frame, metres) */
    int ndigs;
} fk_dig_field;

/* The ground's height in the local frame at (x, z), following the curvature (as fk_planet_grid). */
double fk_dig_ground(const fk_dig_field *f, double x, double z);
/* The solid with the digs at a point: negative inside the ground, positive in the open, about the distance. */
double fk_dig_solid(const fk_dig_field *f, double x, double y, double z);
/* Meshes the dug walls in the cube from lo with n x n x n cells of `cell` metres (n at most FK_DIG_MAX_N): soil
   colour near the top, rock deeper down (sRGB). Returns the number of indices (three per triangle, unshared). */
int fk_dig_mesh(const fk_dig_field *f, const double lo[3], double cell, int n, const float soil[3], const float rock[3],
                fk_vertex *vertices, int max_vertices, uint32_t *indices, int max_indices);
