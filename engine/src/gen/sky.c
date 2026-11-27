/* The night sky from a point in the galaxy (CONCEPT 4.1: the sky is real): the stars within a radius as points of
   their apparent brightness and colour, over the glow of the galactic band, baked into a cube map. */
#include "gen/sky.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "gen/galaxy.h"

void fk_sky_direction(int face, int x, int y, int size, double d[3]) {
    double s = 2.0 * (x + 0.5) / size - 1.0, t = 2.0 * (y + 0.5) / size - 1.0;
    switch (face) { /* the GL cube map convention */
    case 0: d[0] = 1, d[1] = -t, d[2] = -s; break;
    case 1: d[0] = -1, d[1] = -t, d[2] = s; break;
    case 2: d[0] = s, d[1] = 1, d[2] = t; break;
    case 3: d[0] = s, d[1] = -1, d[2] = -t; break;
    case 4: d[0] = s, d[1] = -t, d[2] = 1; break;
    default: d[0] = -s, d[1] = -t, d[2] = -1; break;
    }
    double l = sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]);
    for (int k = 0; k < 3; k++) d[k] /= l;
}

/* The face and texel coordinates (0..size) of a direction. */
static int face_of(const double d[3], int size, double *u, double *v) {
    double ax = fabs(d[0]), ay = fabs(d[1]), az = fabs(d[2]), s, t, m;
    int face;
    if (ax >= ay && ax >= az) face = d[0] > 0 ? 0 : 1, m = ax, s = d[0] > 0 ? -d[2] : d[2], t = -d[1];
    else if (ay >= az) face = d[1] > 0 ? 2 : 3, m = ay, s = d[0], t = d[1] > 0 ? d[2] : -d[2];
    else face = d[2] > 0 ? 4 : 5, m = az, s = d[2] > 0 ? d[0] : -d[0], t = -d[1];
    *u = (s / m + 1.0) * 0.5 * size - 0.5;
    *v = (t / m + 1.0) * 0.5 * size - 0.5;
    return face;
}

static void splat(float *rgb, int size, const double d[3], const float color[3], float b) {
    double u, v;
    int face = face_of(d, size, &u, &v);
    int x0 = (int)floor(u), y0 = (int)floor(v);
    float fx = (float)(u - x0), fy = (float)(v - y0);
    for (int j = 0; j < 2; j++)
        for (int i = 0; i < 2; i++) {
            int x = x0 + i, y = y0 + j;
            if (x < 0 || y < 0 || x >= size || y >= size) continue;
            float w = (i ? fx : 1 - fx) * (j ? fy : 1 - fy) * b;
            float *p = &rgb[((size_t)face * size * size + (size_t)y * size + x) * 3];
            for (int k = 0; k < 3; k++) p[k] += color[k] * w;
        }
}

int fk_sky_bake(uint64_t seed, const double pos[3], double radius, int size, float *rgb) {
    memset(rgb, 0, (size_t)6 * size * size * 3 * sizeof *rgb);
    /* The galactic band: starlight summed along each direction, on a coarse grid, then spread bilinearly. */
    int g = size / 8 > 2 ? size / 8 : 2;
    float *band = malloc((size_t)6 * g * g * sizeof *band);
    if (!band) return -1;
    for (int f = 0; f < 6; f++)
        for (int y = 0; y < g; y++)
            for (int x = 0; x < g; x++) {
                double d[3], sum = 0, step = 300;
                fk_sky_direction(f, x, y, g, d);
                for (double t = 150; t < 30000; t += step, step *= 1.5) {
                    double p[3] = {pos[0] + d[0] * t, pos[1] + d[1] * t, pos[2] + d[2] * t};
                    sum += fk_galaxy_density(p) * step / (1.0 + t / 4000.0); /* distant light fades */
                }
                band[(f * g + y) * g + x] = (float)(sum * 1.4e-4); /* about 0.004 at its brightest, seen from the Sun */
            }
    static const float glow[3] = {1.0f, 0.88f, 0.72f};
    for (int f = 0; f < 6; f++)
        for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++) {
                float gx = (x + 0.5f) * g / size - 0.5f, gy = (y + 0.5f) * g / size - 0.5f;
                int x0 = gx < 0 ? 0 : (int)gx, y0 = gy < 0 ? 0 : (int)gy;
                int x1 = x0 + 1 < g ? x0 + 1 : g - 1, y1 = y0 + 1 < g ? y0 + 1 : g - 1;
                float fx = gx - x0 < 0 ? 0 : gx - x0, fy = gy - y0 < 0 ? 0 : gy - y0;
                const float *b = &band[f * g * g];
                float v = (b[y0 * g + x0] * (1 - fx) + b[y0 * g + x1] * fx) * (1 - fy) + (b[y1 * g + x0] * (1 - fx) + b[y1 * g + x1] * fx) * fy;
                float *p = &rgb[((size_t)f * size * size + (size_t)y * size + x) * 3];
                for (int k = 0; k < 3; k++) p[k] = glow[k] * v;
            }
    free(band);
    /* The stars: brightness from luminosity over distance squared (about 0.03 for Sirius seen from Earth). */
    fk_star *stars = malloc(FK_SECTOR_MAX_STARS * sizeof *stars);
    if (!stars) return -1;
    int64_t lo[3], hi[3], count = 0;
    for (int k = 0; k < 3; k++) lo[k] = (int64_t)floor((pos[k] - radius) / FK_SECTOR_LY), hi[k] = (int64_t)floor((pos[k] + radius) / FK_SECTOR_LY);
    for (int64_t sx = lo[0]; sx <= hi[0]; sx++)
        for (int64_t sy = lo[1]; sy <= hi[1]; sy++)
            for (int64_t sz = lo[2]; sz <= hi[2]; sz++) {
                int n = fk_galaxy_sector(seed, sx, sy, sz, stars);
                for (int i = 0; i < n; i++) {
                    double d[3] = {stars[i].pos[0] - pos[0], stars[i].pos[1] - pos[1], stars[i].pos[2] - pos[2]};
                    double r2 = d[0] * d[0] + d[1] * d[1] + d[2] * d[2], r = sqrt(r2);
                    if (r > radius || r < 0.01) continue; /* too far, or the system's own star */
                    float b = (float)(stars[i].luminosity / r2 * 0.1);
                    if (b < 1e-4f) continue;
                    if (b > 2) b = 2;
                    for (int k = 0; k < 3; k++) d[k] /= r;
                    splat(rgb, size, d, stars[i].color, b);
                    count++;
                }
            }
    free(stars);
    return (int)count;
}
