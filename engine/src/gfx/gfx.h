/* Renderer. M0: clear, coloured meshes with one transform, frame read-back. */
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    uint32_t vao, vbo, ibo;
    int count; /* number of indices */
} fk_mesh;

/* Loads the GL functions and compiles the shader (one file with VERTEX and FRAGMENT sections).
   Needs a current context. Logs and returns false on failure. */
bool fk_gfx_init(const char *shader_source);
void fk_gfx_shutdown(void);
void fk_gfx_viewport(int w, int h);
void fk_gfx_clear(float r, float g, float b);
/* vertices: x, y, z, r, g, b per vertex; indices: triangles, 0-based. */
void fk_gfx_mesh_create(fk_mesh *m, const float *vertices, int vertex_count, const uint32_t *indices, int index_count);
void fk_gfx_mesh_destroy(fk_mesh *m);
/* mvp: column-major 4x4 matrix. */
void fk_gfx_mesh_draw(const fk_mesh *m, const float mvp[16]);
/* Reads the current frame as RGBA, top row first. */
void fk_gfx_read_pixels(int w, int h, uint8_t *rgba);
