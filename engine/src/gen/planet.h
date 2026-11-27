/* Planet surfaces from space (CONCEPT 4.4, 4.5): a cube sphere split into chunks by a quadtree; a chunk's mesh is
   built from the planet's noise graphs and fields (elevation, temperature by latitude and height, moisture, sea level,
   ice), so the same function serves every level of detail and, in M5, the ground. Plain C, deterministic, read-only
   inputs: chunks are built in jobs. */
#pragma once
#include <stdbool.h>
#include <stdint.h>

#include "gen/noise.h"
#include "gfx/gfx.h"

enum { FK_PAL_DEEP, FK_PAL_SHALLOW, FK_PAL_BEACH, FK_PAL_LOW, FK_PAL_MID, FK_PAL_HIGH, FK_PAL_PEAK, FK_PAL_ICE,
       FK_PAL_GRASS, FK_PAL_FOREST, FK_PAL_DESERT, FK_PAL_TUNDRA, FK_PAL_COUNT };

typedef struct fk_planet {
    double radius;      /* metres, at height 0 */
    double relief;      /* metres per unit of the height graph */
    double sea_level;   /* height units; ocean below it when ocean is set */
    bool ocean, life;   /* life: vegetation biomes on land */
    bool bands;         /* gas and ice giants: coloured by latitude bands, no relief */
    double temperature; /* kelvin at the equator, at sea level */
    double ice_latitude;/* |y| above which the poles are ice */
    float palette[FK_PAL_COUNT][3]; /* sRGB */
    fk_noise height, moisture;      /* moisture.count == 0: none (dry) */
    fk_noise clouds;                /* clouds.count == 0: none; stored in the vertices' u for the draw to fade */
    double cloud_cover;             /* 0..1 */
    double site[3], site_radius;    /* a levelled site (the range's pad): flat within site_radius metres of the */
    double site_height;             /* unit direction site, easing back to the land over as far again; radius 0: none */
    const struct fk_hydro *hydro;   /* rivers carved into the ground around the range (rivers-and-lakes spec), or NULL */
} fk_planet;

#define FK_CHUNK_GRID 32 /* quads along a chunk's edge */
#define FK_CHUNK_VERTICES ((FK_CHUNK_GRID + 1) * (FK_CHUNK_GRID + 1) + 4 * (FK_CHUNK_GRID + 1))
#define FK_CHUNK_INDICES (FK_CHUNK_GRID * FK_CHUNK_GRID * 6 + 4 * FK_CHUNK_GRID * 6)

/* The unit direction of face coordinates (u, v in -1..1) on a cube face (0..5: +x, -x, +y, -y, +z, -z), spread
   evenly over the sphere. */
void fk_cube_to_sphere(int face, double u, double v, double d[3]);
/* Height (metres above the radius; under an ocean, its floor) and colour (sRGB) at a unit direction. */
double fk_planet_height(const fk_planet *p, const double d[3]);
void fk_planet_color(const fk_planet *p, const double d[3], double height, float rgb[3]);
/* Builds chunk (face, level, x, y): vertices relative to centre (metres, planet axes), skirts included. Fills centre
   (planet axes) and returns the chunk's bounding radius around it. */
/* Levels the ground within radius metres of unit direction d to its height there (before any chunk is built). */
void fk_planet_flatten(fk_planet *p, const double d[3], double radius);
/* Heights for a terrain grid in a local frame on the surface (y along up, x along east, z along north, unit vectors,
   origin on the surface at up): (n + 1)^2 heights, row by row from (x0, z0), relative to the ground at the origin,
   following the curvature. */
void fk_planet_grid(const fk_planet *p, const double up[3], const double east[3], const double north[3], double x0,
                    double z0, double cell, int n, float *heights, float *colors /* NULL, or sRGB r, g, b per height */);
/* The surface layers at a direction: snow cover (cold, polar) and wetness (shores), each 0..1. */
void fk_planet_layers(const fk_planet *p, const double d[3], double height, double *snow, double *wet);
double fk_planet_chunk(const fk_planet *p, int face, int level, int x, int y, fk_vertex *vertices, uint32_t *indices,
                       double centre[3]);
