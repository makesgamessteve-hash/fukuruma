/* Renderer: meshes, and the pipeline that renders the recorded frame (see gfx/frame.h). */
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    uint32_t vao, vbo, ibo;
    int count; /* number of indices */
} fk_mesh;

/* Loads the GL functions, compiles the shaders and creates the targets for the current settings.
   Needs a current context. Logs and returns false on failure. */
bool fk_gfx_init(void);
void fk_gfx_shutdown(void);
/* Applies fk_gfx_settings_current() (targets, shader variants). Forces HDR off when unsupported. */
bool fk_gfx_configure(void);
/* Renders the recorded frame into the internal image and shows it in the window. dt: seconds since the last frame. */
void fk_gfx_render(double dt, int window_w, int window_h);
void fk_gfx_clear_window(float r, float g, float b);
/* Reads the finished internal image (settings width x height) as RGBA, top row first. */
void fk_gfx_read_pixels(uint8_t *rgba);
/* vertices: x, y, z, r, g, b, nx, ny, nz per vertex; indices: triangles, 0-based. */
void fk_gfx_mesh_create(fk_mesh *m, const float *vertices, int vertex_count, const uint32_t *indices, int index_count);
void fk_gfx_mesh_destroy(fk_mesh *m);
