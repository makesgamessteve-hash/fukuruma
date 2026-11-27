/* The night sky seen from a point in the galaxy, baked into a cube map (gen/sky.c). Plain C, no GL. */
#pragma once
#include <stdint.h>

/* Fills rgb (6 faces of size x size linear RGB floats, in GL cube map order +x, -x, +y, -y, +z, -z, rows from the top)
   with the galactic band and the stars within radius light-years of pos (galaxy coordinates). Returns the number of
   stars drawn, or -1 when out of memory. */
int fk_sky_bake(uint64_t galaxy_seed, const double pos[3], double radius, int size, float *rgb);
/* The unit direction through the centre of texel (x, y) of a face. */
void fk_sky_direction(int face, int x, int y, int size, double d[3]);
