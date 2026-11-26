/* Renderer: meshes, and the pipeline that renders the recorded frame (see gfx/frame.h). */
#pragma once
#include <stdbool.h>
#include <stdint.h>

/* The one vertex layout of scene meshes. colour: sRGB; tangent.w: bitangent sign; joints and weights:
   up to four bone influences (used by skinned draws only). */
typedef struct {
    float position[3], color[3], normal[3], uv[2], tangent[4], joints[4], weights[4];
} fk_vertex;

typedef struct {
    uint32_t vao, vbo, ibo;
    int count; /* number of indices */
} fk_mesh;

typedef struct {
    uint32_t id;
    int width, height;
} fk_texture;

/* Loads the GL functions, compiles the shaders and creates the targets for the current settings.
   Needs a current context. Logs and returns false on failure. */
bool fk_gfx_init(void);
void fk_gfx_shutdown(void);
/* Applies fk_gfx_settings_current() (targets, shader variants). Forces HDR off when unsupported. */
bool fk_gfx_configure(void);
/* Renders the recorded frame into the internal image and shows it in the window. dt: seconds since the last frame. */
void fk_gfx_render(double dt, int window_w, int window_h);
void fk_gfx_clear_window(float r, float g, float b);
/* The GL renderer's name, e.g. "llvmpipe (LLVM 20.1, 256 bits)" (empty before fk_gfx_init). */
const char *fk_gfx_renderer(void);
/* Reads the finished internal image (settings width x height) as RGBA, top row first. */
void fk_gfx_read_pixels(uint8_t *rgba);
/* indices: triangles, 0-based. */
void fk_gfx_mesh_create(fk_mesh *m, const fk_vertex *vertices, int vertex_count, const uint32_t *indices, int index_count);
void fk_gfx_mesh_destroy(fk_mesh *m);
/* rgba: width x height RGBA8 pixels, top row first. srgb: colour data (base colour, emission) rather than
   linear data (normals, roughness). Creates the mipmaps. Replaces the pixels of an existing texture. */
void fk_gfx_texture_upload(fk_texture *t, const uint8_t *rgba, int width, int height, bool srgb);
void fk_gfx_texture_destroy(fk_texture *t);
