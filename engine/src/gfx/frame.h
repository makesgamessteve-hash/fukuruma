/* What a frame should show, recorded by scripts before the pipeline renders it. Plain C, no GL. */
#pragma once
#include <stdbool.h>
#include <stdint.h>

#include "gfx/gfx.h"

#define FK_MAX_LIGHTS 32

typedef struct {
    int width, height;   /* internal resolution */
    int supersample;     /* 1 or 2 */
    int shadow_cascades; /* 0 to 4 */
    int shadow_size;     /* 256 to 4096 */
    int ao_samples;      /* 0 to 16 */
    int max_lights;      /* 0 to FK_MAX_LIGHTS */
    bool bloom, hdr, dither;
} fk_gfx_settings;

typedef struct {
    float roughness, metalness, emission[3]; /* emission: linear radiance added to the surface */
} fk_material;

typedef struct {
    const fk_mesh *mesh;
    float model[16];
    fk_material material;
} fk_draw;

typedef struct {
    const fk_mesh *mesh;
    float matrix[16];
} fk_overlay;

typedef struct {
    float position[3], color[3], radius; /* color: linear, times intensity */
} fk_point_light;

typedef struct {
    float view[16], projection[16];
    float background[3];            /* linear */
    float sun_dir[3], sun_color[3]; /* towards the star; linear colour times intensity */
    float sky[3], ground[3];        /* ambient, linear colour times intensity */
    float exposure, contrast, saturation, tint[3];
    fk_point_light lights[FK_MAX_LIGHTS];
    int nlights;
    fk_draw *draws;
    int ndraws, draw_cap;
    fk_overlay *overlays;
    int noverlays, overlay_cap;
} fk_frame;

fk_frame *fk_frame_get(void);
void fk_frame_reset(void); /* defaults for camera, lights and grading; empties the lists */
void fk_frame_begin(void); /* empties draws, overlays and point lights for a new frame */
void fk_frame_draw(const fk_mesh *mesh, const float model[16], const fk_material *material);
void fk_frame_overlay(const fk_mesh *mesh, const float matrix[16]);
void fk_frame_light(const fk_point_light *light); /* lights beyond FK_MAX_LIGHTS are ignored */
float fk_srgb_to_linear(float c);

void fk_gfx_settings_default(fk_gfx_settings *s);
fk_gfx_settings *fk_gfx_settings_current(void);
const char *fk_gfx_settings_check(const fk_gfx_settings *s); /* NULL when valid, else the bad field's name */

/* The integer-scaled, centred rectangle (x, y, w, h in window pixels) for an image in a window. */
void fk_gfx_upscale_rect(int win_w, int win_h, int img_w, int img_h, int rect[4]);
/* Remembers the window size and image rectangle for mapping input positions. */
void fk_gfx_set_window(int win_w, int win_h, const int rect[4]);
/* Maps a position normalised to the window to one normalised to the image (identity without a window). */
void fk_gfx_map_point(float *x, float *y);
void fk_gfx_map_delta(float *dx, float *dy); /* the same for movements */

/* Fills in vertex normals (offset 6 of each 9-float vertex) from the triangles that use each vertex. */
void fk_mesh_normals(float *vertices, int vertex_count, const uint32_t *indices, int index_count);
