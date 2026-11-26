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
    bool taa;  /* temporal anti-aliasing */
    bool fill; /* the internal image takes the window's shape; height is the target */
} fk_gfx_settings;

typedef struct {
    float base[4];                           /* linear colour factor; multiplies the vertex colour and texture */
    float roughness, metalness, emission[3]; /* emission: linear radiance added to the surface */
    float normal_scale;
    const fk_texture *base_tex, *metal_rough_tex, *normal_tex, *emission_tex; /* NULL: none */
} fk_material;

void fk_material_default(fk_material *m); /* white, roughness 0.6, not metallic, no emission, no textures */

typedef struct {
    const fk_mesh *mesh;
    float model[16];
    fk_material material;
} fk_draw;

#define FK_MAX_PALETTE 64

/* A textured quad of the sprite batch (text and rectangles), in internal-image pixels. */
typedef struct {
    float x, y, w, h, u0, v0, u1, v1, color[4];
} fk_sprite;

/* Overlay items in draw order: a mesh, or a run of sprites (mesh == NULL). */
typedef struct {
    const fk_mesh *mesh;
    float matrix[16];
    int first, count;
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
    fk_sprite *sprites;
    int nsprites, sprite_cap;
    float palette[FK_MAX_PALETTE][3]; /* sRGB */
    int palette_size;                 /* 0: palette mode off */
} fk_frame;

fk_frame *fk_frame_get(void);
void fk_frame_reset(void); /* defaults for camera, lights and grading; empties the lists */
void fk_frame_begin(void); /* empties draws, overlays and point lights for a new frame */
void fk_frame_draw(const fk_mesh *mesh, const float model[16], const fk_material *material);
void fk_frame_overlay(const fk_mesh *mesh, const float matrix[16]);
void fk_frame_light(const fk_point_light *light); /* lights beyond FK_MAX_LIGHTS are ignored */
/* Text in the 8x8 font at whole pixels; characters outside printable ASCII are drawn as '?'. */
void fk_frame_text(float x, float y, const char *text, const float color[4]);
void fk_frame_rect(float x, float y, float w, float h, const float color[4]);
/* Element index of the 2, 3 Halton sequences, centred on 0 (-0.5..0.5): sub-pixel jitter for TAA. */
float fk_halton(int index, int base);
float fk_srgb_to_linear(float c);

void fk_gfx_settings_default(fk_gfx_settings *s);
fk_gfx_settings *fk_gfx_settings_current(void);
const char *fk_gfx_settings_check(const fk_gfx_settings *s); /* NULL when valid, else the bad field's name */

/* The internal image size for a window: the configured size, or with fill the window divided by
   floor(window_h / height) when the window is at least as large as the configured size. */
void fk_gfx_internal_size(const fk_gfx_settings *s, int win_w, int win_h, int *w, int *h);
/* The internal image size in use (set by configure and by the pipeline when filling the window). */
void fk_gfx_image_size(int *w, int *h);
void fk_gfx_set_image_size(int w, int h);

/* The integer-scaled, centred rectangle (x, y, w, h in window pixels) for an image in a window. */
void fk_gfx_upscale_rect(int win_w, int win_h, int img_w, int img_h, int rect[4]);
/* Remembers the window size and image rectangle for mapping input positions. */
void fk_gfx_set_window(int win_w, int win_h, const int rect[4]);
/* Maps a position normalised to the window to one normalised to the image (identity without a window). */
void fk_gfx_map_point(float *x, float *y);
void fk_gfx_map_delta(float *dx, float *dy); /* the same for movements */

/* Fills in vertex normals from the triangles that use each vertex. */
void fk_mesh_normals(fk_vertex *vertices, int vertex_count, const uint32_t *indices, int index_count);
/* Fills in tangents (with the bitangent sign in w) from the UVs; needs the normals. */
void fk_mesh_tangents(fk_vertex *vertices, int vertex_count, const uint32_t *indices, int index_count);
