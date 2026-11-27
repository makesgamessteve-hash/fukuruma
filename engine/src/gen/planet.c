#include "gen/planet.h"

#include "core/dmath.h"

#include <math.h>
#include <string.h>

void fk_cube_to_sphere(int face, double u, double v, double d[3]) {
    double c[3];
    switch (face) { /* the same orientation as the cube map faces */
    case 0: c[0] = 1, c[1] = -v, c[2] = -u; break;
    case 1: c[0] = -1, c[1] = -v, c[2] = u; break;
    case 2: c[0] = u, c[1] = 1, c[2] = v; break;
    case 3: c[0] = u, c[1] = -1, c[2] = -v; break;
    case 4: c[0] = u, c[1] = -v, c[2] = 1; break;
    default: c[0] = -u, c[1] = -v, c[2] = -1; break;
    }
    /* spread the cube's points evenly (the "spherified cube" mapping) */
    double x2 = c[0] * c[0], y2 = c[1] * c[1], z2 = c[2] * c[2];
    d[0] = c[0] * sqrt(1 - y2 / 2 - z2 / 2 + y2 * z2 / 3);
    d[1] = c[1] * sqrt(1 - z2 / 2 - x2 / 2 + z2 * x2 / 3);
    d[2] = c[2] * sqrt(1 - x2 / 2 - y2 / 2 + x2 * y2 / 3);
}

static double raw(const fk_planet *p, const double d[3]) {
    return p->bands ? 0 : fk_noise_eval(&p->height, d[0], d[1], d[2]);
}

static double natural(const fk_planet *p, const double d[3]) {
    double h = raw(p, d);
    if (p->ocean && h < p->sea_level) h = p->sea_level; /* the ocean's surface */
    return (h - p->sea_level) * p->relief;
}

double fk_planet_height(const fk_planet *p, const double d[3]) {
    double h = natural(p, d);
    if (p->site_radius > 0) {
        double dx = d[0] - p->site[0], dy = d[1] - p->site[1], dz = d[2] - p->site[2];
        double k = (sqrt(dx * dx + dy * dy + dz * dz) * p->radius - p->site_radius) / p->site_radius; /* 0..1: easing */
        if (k < 1) {
            k = k < 0 ? 0 : k * k * (3 - 2 * k);
            h = p->site_height + (h - p->site_height) * k;
        }
    }
    return h;
}

void fk_planet_flatten(fk_planet *p, const double d[3], double radius) {
    p->site_radius = 0;
    p->site_height = natural(p, d);
    memcpy(p->site, d, sizeof p->site);
    p->site_radius = radius;
}

void fk_planet_grid(const fk_planet *p, const double up[3], const double east[3], const double north[3], double x0,
                    double z0, double cell, int n, float *heights, float *colors) {
    double base = p->radius + fk_planet_height(p, up);
    for (int j = 0; j <= n; j++)
        for (int i = 0; i <= n; i++) {
            double x = x0 + i * cell, z = z0 + j * cell, d[3], l = 0;
            for (int k = 0; k < 3; k++) d[k] = up[k] * p->radius + east[k] * x + north[k] * z, l += d[k] * d[k];
            l = sqrt(l);
            for (int k = 0; k < 3; k++) d[k] /= l;
            double h = fk_planet_height(p, d), r = p->radius + h, cosine = d[0] * up[0] + d[1] * up[1] + d[2] * up[2];
            heights[j * (n + 1) + i] = (float)(r * cosine - base);
            if (colors) fk_planet_color(p, d, h, &colors[3 * (j * (n + 1) + i)]);
        }
}

static void mix(float out[3], const float a[3], const float b[3], double t) {
    t = t < 0 ? 0 : t > 1 ? 1 : t;
    for (int i = 0; i < 3; i++) out[i] = (float)(a[i] + (b[i] - a[i]) * t);
}

void fk_planet_color(const fk_planet *p, const double d[3], double height, float rgb[3]) {
    const float(*pal)[3] = p->palette;
    double lat = fabs(d[1]);
    if (p->bands) { /* belts and zones, bent by turbulence */
        double turb = p->height.count ? fk_noise_eval(&p->height, d[0], d[1], d[2]) * 0.08 : 0;
        double b = 0.5 + 0.5 * fk_dsin((d[1] + turb) * 18.0), polar = (lat - 0.75) / 0.25;
        mix(rgb, pal[FK_PAL_LOW], pal[FK_PAL_MID], b);
        if (polar > 0) mix(rgb, rgb, pal[FK_PAL_HIGH], polar);
        return;
    }
    double h = raw(p, d) - p->sea_level;
    double temp = p->temperature - 60 * lat * lat - 0.0065 * (height > 0 ? height : 0);
    if (p->ocean && h < 0) {
        mix(rgb, pal[FK_PAL_SHALLOW], pal[FK_PAL_DEEP], -h * 6);
        if (temp < 262) mix(rgb, rgb, pal[FK_PAL_ICE], (262 - temp) / 6); /* frozen seas */
        return;
    }
    double up = h / 0.6; /* 0 at the shore, 1 high up */
    if (up < 0.5) mix(rgb, pal[FK_PAL_LOW], pal[FK_PAL_MID], up * 2);
    else mix(rgb, pal[FK_PAL_MID], pal[FK_PAL_HIGH], up * 2 - 1);
    if (p->life) {
        double wet = p->moisture.count ? 0.5 + 0.5 * fk_noise_eval(&p->moisture, d[0], d[1], d[2]) : 0.5;
        float green[3];
        if (temp < 268) memcpy(green, pal[FK_PAL_TUNDRA], sizeof green);
        else if (wet < 0.35 && temp > 288) memcpy(green, pal[FK_PAL_DESERT], sizeof green);
        else mix(green, pal[FK_PAL_GRASS], pal[FK_PAL_FOREST], (wet - 0.4) * 3);
        mix(rgb, green, rgb, up * 1.6 - 0.3); /* vegetation thins out with height */
    }
    if (p->ocean && h < 0.015) mix(rgb, pal[FK_PAL_BEACH], rgb, h / 0.015);
    if (up > 0.8) mix(rgb, rgb, pal[FK_PAL_PEAK], (up - 0.8) * 4);
    if (temp < 255 || lat > p->ice_latitude) mix(rgb, rgb, pal[FK_PAL_ICE], temp < 255 ? (255 - temp) / 10 : (lat - p->ice_latitude) * 20);
}

void fk_planet_layers(const fk_planet *p, const double d[3], double height, double *snow, double *wet) {
    *snow = *wet = 0;
    if (p->bands) return;
    double lat = fabs(d[1]), h = raw(p, d) - p->sea_level;
    double temp = p->temperature - 60 * lat * lat - 0.0065 * (height > 0 ? height : 0);
    if (p->ocean && h < 0) return; /* the sea itself: water (M5 add-water) */
    *snow = (268 - temp) / 10;
    if (lat > p->ice_latitude) *snow = 1;
    *snow = *snow < 0 ? 0 : *snow > 1 ? 1 : *snow;
    if (p->ocean && h < 0.03) *wet = 1 - h / 0.03; /* the shore (rain adds wetness everywhere: the weather) */
}

static void surface(const fk_planet *p, int face, double u, double v, double pos[3], double d[3], double *height) {
    fk_cube_to_sphere(face, u, v, d);
    *height = fk_planet_height(p, d);
    double r = p->radius + *height;
    for (int k = 0; k < 3; k++) pos[k] = d[k] * r;
}

double fk_planet_chunk(const fk_planet *p, int face, int level, int x, int y, fk_vertex *vertices, uint32_t *indices,
                       double centre[3]) {
    const int N = FK_CHUNK_GRID, row = N + 1;
    /* each chunk overlaps its neighbours by a hair, so float rounding leaves no pixel-wide cracks between them */
    double size = 2.0 / (double)(1 << level), pad = size * 0.002, u0 = -1 + x * size - pad, v0 = -1 + y * size - pad;
    double step = (size + 2 * pad) / N;
    double cd[3];
    fk_cube_to_sphere(face, u0 + pad + size / 2, v0 + pad + size / 2, cd);
    double ground = p->radius + fk_planet_height(p, cd); /* on the surface: tight bounds, precise vertices */
    for (int k = 0; k < 3; k++) centre[k] = cd[k] * ground;
    double bound = 0, skirt = p->radius * size * 0.0125 + 1; /* half a quad: deep enough for the cracks */
    memset(vertices, 0, (size_t)FK_CHUNK_VERTICES * sizeof *vertices);
    for (int j = 0; j <= N; j++)
        for (int i = 0; i <= N; i++) {
            double pos[3], d[3], h, e = step * 0.25, a[3], b[3], da[3], db[3], ha, hb;
            surface(p, face, u0 + i * step, v0 + j * step, pos, d, &h);
            /* the normal from two nearby surface points: the same on both sides of a chunk border */
            surface(p, face, u0 + i * step + e, v0 + j * step, a, da, &ha);
            surface(p, face, u0 + i * step, v0 + j * step + e, b, db, &hb);
            double ta[3] = {a[0] - pos[0], a[1] - pos[1], a[2] - pos[2]}, tb[3] = {b[0] - pos[0], b[1] - pos[1], b[2] - pos[2]};
            double n[3] = {tb[1] * ta[2] - tb[2] * ta[1], tb[2] * ta[0] - tb[0] * ta[2], tb[0] * ta[1] - tb[1] * ta[0]};
            double nl = sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
            if (n[0] * d[0] + n[1] * d[1] + n[2] * d[2] < 0) nl = -nl; /* outwards */
            fk_vertex *vx = &vertices[j * row + i];
            for (int k = 0; k < 3; k++) {
                vx->position[k] = (float)(pos[k] - centre[k]);
                vx->normal[k] = (float)(nl != 0 ? n[k] / nl : d[k]);
            }
            fk_planet_color(p, d, h, vx->color);
            double snow, wet; /* the surface layers for the terrain material, in the (otherwise unused) tangent */
            fk_planet_layers(p, d, h, &snow, &wet);
            vx->tangent[0] = (float)snow, vx->tangent[1] = (float)wet;
            if (p->clouds.count) { /* the cloud layer as seen from far away, in u: the draw fades it (option clouds) */
                double c = 0.5 + 0.5 * fk_noise_eval(&p->clouds, d[0], d[1], d[2]), t = (c - (1 - p->cloud_cover)) / 0.15;
                vx->uv[0] = (float)((t < 0 ? 0 : t > 1 ? 1 : t) * 0.9);
            }
            double r2 = (pos[0] - centre[0]) * (pos[0] - centre[0]) + (pos[1] - centre[1]) * (pos[1] - centre[1]) +
                        (pos[2] - centre[2]) * (pos[2] - centre[2]);
            if (r2 > bound) bound = r2;
        }
    /* Skirts: the border vertices again, lowered, so neighbours of another level leave no cracks. */
    int s = row * row;
    for (int side = 0; side < 4; side++)
        for (int k = 0; k <= N; k++) {
            int i = side == 0 ? k : side == 1 ? N : side == 2 ? N - k : 0;
            int j = side == 0 ? 0 : side == 1 ? k : side == 2 ? N : N - k;
            fk_vertex *src = &vertices[j * row + i], *dst = &vertices[s + side * row + k];
            *dst = *src;
            double pos[3], len = 0;
            for (int q = 0; q < 3; q++) pos[q] = src->position[q] + centre[q], len += pos[q] * pos[q];
            len = sqrt(len);
            for (int q = 0; q < 3; q++) dst->position[q] = (float)(pos[q] - pos[q] / len * skirt - centre[q]);
        }
    uint32_t *ix = indices;
    for (int j = 0; j < N; j++)
        for (int i = 0; i < N; i++) {
            uint32_t a = (uint32_t)(j * row + i), b = a + 1, c = a + (uint32_t)row, d = c + 1;
            *ix++ = a, *ix++ = c, *ix++ = b, *ix++ = b, *ix++ = c, *ix++ = d;
        }
    for (int side = 0; side < 4; side++)
        for (int k = 0; k < N; k++) {
            int i0 = side == 0 ? k : side == 1 ? N : side == 2 ? N - k : 0, j0 = side == 0 ? 0 : side == 1 ? k : side == 2 ? N : N - k;
            int i1 = side == 0 ? k + 1 : side == 1 ? N : side == 2 ? N - k - 1 : 0;
            int j1 = side == 0 ? 0 : side == 1 ? k + 1 : side == 2 ? N : N - k - 1;
            uint32_t top0 = (uint32_t)(j0 * row + i0), top1 = (uint32_t)(j1 * row + i1);
            uint32_t low0 = (uint32_t)(s + side * row + k), low1 = low0 + 1;
            *ix++ = top0, *ix++ = top1, *ix++ = low0, *ix++ = top1, *ix++ = low1, *ix++ = low0;
        }
    return sqrt(bound);
}
