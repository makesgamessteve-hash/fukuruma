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
    int max_particles;   /* 0 to 65536 */
    bool bloom, hdr, dither;
    bool taa;  /* temporal anti-aliasing */
    bool fill; /* the internal image takes the window's shape; height is the target */
    bool clouds; /* the cloud layer's code is compiled into the shaders (software renderers run it even when unused) */
} fk_gfx_settings;

typedef struct {
    float base[4];                           /* linear colour factor; multiplies the vertex colour and texture */
    float roughness, metalness, emission[3]; /* emission: linear radiance added to the surface */
    float normal_scale;
    bool one_sided; /* closed surfaces seen from outside: back faces keep their normals (no two-sided flip) */
    bool emissive_colors; /* the vertex colours tint the emission (stars) */
    float clouds; /* 0..1: how much of the cloud cover stored in the vertices' u shows (planet chunks) */
    int terrain; /* the terrain material's quality (planet chunks near the ground), 0: none; 1 layers (rock, snow,
                    wetness, dust), 2 with detail, 3 with bumps as well */
    float terrain_origin[3]; /* the chunk's centre (planet axes, metres) wrapped to the detail's period */
    float terrain_up[3];     /* the world's up at the chunk, in draw axes */
    float weather[3];        /* extra wetness, snow and dust from the weather, 0..1 */
    float digs[16][4];       /* terrain: dug spheres (draw axes; x, y, z, radius) whose inside is left out */
    int ndigs;
    const fk_instances *instances; /* NULL: one; else the mesh is drawn once per instance */
    const fk_texture *base_tex, *metal_rough_tex, *normal_tex, *emission_tex; /* NULL: none */
} fk_material;

void fk_material_default(fk_material *m); /* white, roughness 0.6, not metallic, no emission, no textures */

/* Depth slices: layers drawn with their own near and far planes into their own part of the depth buffer, so a
   nearer slice is always in front of a farther one. FK_SLICE_LOCAL uses the camera's projection as it is. */
enum { FK_SLICE_NEAR, FK_SLICE_LOCAL, FK_SLICE_PLANETARY, FK_SLICE_CELESTIAL, FK_SLICE_COUNT };

/* The part of the depth buffer each slice writes, from FK_SLICE_DEPTH[i] to FK_SLICE_DEPTH[i + 1]. */
extern const float FK_SLICE_DEPTH[FK_SLICE_COUNT + 1];

typedef struct {
    const fk_mesh *mesh;
    float model[16];
    fk_material material;
    int bone_offset; /* first matrix in the frame's bones, -1: not skinned */
    int slice;       /* FK_SLICE_* */
} fk_draw;

#define FK_MAX_FRAME_BONES 4096 /* skinned draws beyond this are drawn in their bind pose */

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

/* The sea of the world the camera is at (water spec): a sphere about centre at radius (sea level). */
typedef struct {
    bool on;
    float centre[3], radius;
    float deep[3], shallow[3]; /* linear colours of deep and shallow water */
    float time, waves;         /* presentation seconds; wave height (metres) */
} fk_water;

/* The air of the world the camera is at or looking at (one per frame), for atmospheric scattering. */
typedef struct {
    bool on;
    float centre[3];           /* camera-relative world space */
    float radius, top, height; /* surface, top of the air, Rayleigh scale height */
    float rayleigh[3], mie, absorb[3]; /* per metre at the surface */
    float ground[3];                   /* linear albedo of the surface beyond what is drawn */
    /* clouds (volumetric-clouds-and-fog spec): a layer between bottom and top (metres above the surface), cover 0..1,
       density per metre inside a cloud, the wind's drift (metres, the same axes as centre); steps 0: none */
    float cloud_bottom, cloud_top, cloud_cover, cloud_density, cloud_offset[3];
    int cloud_steps;
    float fog_density, fog_height; /* ground fog: extinction per metre at the surface, scale height (metres) */
} fk_atmosphere;

typedef struct {
    float view[16], projection[16];
    float background[3];            /* linear */
    float sun_dir[3], sun_color[3]; /* towards the star; linear colour times intensity */
    float sun2_dir[3], sun2_color[3]; /* a second star (binaries): no shadows; colour 0 when there is none */
    float wind[4];                    /* wind for instanced meshes: x, z (draw axes, strength in the length) and time */
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
    float *bones; /* 16 floats per bone matrix, for skinned draws */
    int nbones, bone_cap;
    float palette[FK_MAX_PALETTE][3]; /* sRGB */
    int palette_size;                 /* 0: palette mode off */
    float slice_near[FK_SLICE_COUNT], slice_far[FK_SLICE_COUNT]; /* metres; FK_SLICE_LOCAL's are unused */
    int slice; /* the slice of the next draws */
    int triangles; /* drawn this frame (budgets) */
    const fk_texture *sky_map; /* a cube map shown where nothing is drawn, or NULL */
    float sky_strength;     /* multiplies the sky */
    float sky_rotation[9];  /* turns world directions into the sky's (column-major) */
    fk_atmosphere atmosphere;
    fk_water water;
    float stereo_ipd; /* metres between the eyes: > 0 renders both eyes side by side (webxr spec); kept across frames */
} fk_frame;

fk_frame *fk_frame_get(void);
void fk_frame_reset(void); /* defaults for camera, lights and grading; empties the lists */
void fk_frame_begin(void); /* empties draws, overlays and point lights for a new frame */
void fk_frame_draw(const fk_mesh *mesh, const float model[16], const fk_material *material);
/* Stores count bone matrices for skinned draws and returns their offset, or -1 when the frame is full. */
int fk_frame_bones(const float *matrices, int count);
/* A skinned draw: vertices are moved by the bone matrices stored at bone_offset (see fk_frame_bones). */
void fk_frame_draw_skinned(const fk_mesh *mesh, const float model[16], const fk_material *material, int bone_offset);
void fk_frame_overlay(const fk_mesh *mesh, const float matrix[16]);
void fk_frame_light(const fk_point_light *light); /* lights beyond FK_MAX_LIGHTS are ignored */
/* Text in the 8x8 font at whole pixels; characters outside printable ASCII are drawn as '?'. */
void fk_frame_text(float x, float y, const char *text, const float color[4]);
void fk_frame_rect(float x, float y, float w, float h, const float color[4]);
/* The projection of a slice: the camera's perspective projection with the slice's near and far planes (an
   orthographic projection, and FK_SLICE_LOCAL, are used as they are). */
void fk_frame_slice_projection(const fk_frame *f, int slice, float out[16]);
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
