#include "gfx/frame.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "core/mat4.h"

static fk_frame frame;
static fk_gfx_settings settings = {480, 270, 1, 2, 1024, 8, 8, 4096, true, true, true, false, true};
static int window[2] = {1, 1}, image[4] = {0, 0, 1, 1}, image_size[2] = {480, 270};

const float FK_SLICE_DEPTH[FK_SLICE_COUNT + 1] = {0.0f, 0.03f, 0.75f, 0.9f, 0.9999f}; /* 1: the sky */

fk_frame *fk_frame_get(void) { return &frame; }

void fk_frame_slice_projection(const fk_frame *f, int slice, float out[16]) {
    memcpy(out, f->projection, 16 * sizeof(float));
    if (slice == FK_SLICE_LOCAL || f->projection[11] != -1.0f) return;
    float n = f->slice_near[slice], far = f->slice_far[slice];
    out[10] = -(far + n) / (far - n);
    out[14] = -2.0f * far * n / (far - n);
}

float fk_srgb_to_linear(float c) { return powf(fmaxf(c, 0.0f), 2.2f); }

void fk_frame_reset(void) {
    fk_frame_begin();
    fk_mat4_identity(frame.view);
    fk_mat4_identity(frame.projection);
    const float bg[3] = {0.02f, 0.025f, 0.06f}, sun[3] = {0.4f, 0.8f, 0.3f};
    float len = sqrtf(sun[0] * sun[0] + sun[1] * sun[1] + sun[2] * sun[2]);
    for (int i = 0; i < 3; i++) {
        frame.background[i] = fk_srgb_to_linear(bg[i]);
        frame.sun_dir[i] = sun[i] / len;
        frame.sun_color[i] = 3.0f;
        frame.tint[i] = 1.0f;
    }
    frame.sky[0] = 0.25f, frame.sky[1] = 0.3f, frame.sky[2] = 0.4f;
    frame.ground[0] = 0.08f, frame.ground[1] = 0.07f, frame.ground[2] = 0.06f;
    frame.exposure = 0, frame.contrast = 1, frame.saturation = 1;
    frame.palette_size = 0;
    const float near[FK_SLICE_COUNT] = {0.01f, 0, 400.0f, 5e4f}, far[FK_SLICE_COUNT] = {4.0f, 0, 2e7f, 1e9f};
    memcpy(frame.slice_near, near, sizeof near);
    memcpy(frame.slice_far, far, sizeof far);
    frame.slice = FK_SLICE_LOCAL;
    frame.sky_map = NULL, frame.sky_strength = 0;
    memset(frame.sun2_color, 0, sizeof frame.sun2_color);
    frame.atmosphere.on = false;
    memset(frame.sky_rotation, 0, sizeof frame.sky_rotation);
    frame.sky_rotation[0] = frame.sky_rotation[4] = frame.sky_rotation[8] = 1;
}

void fk_frame_begin(void) {
    frame.ndraws = frame.noverlays = frame.nlights = frame.nsprites = frame.nbones = frame.triangles = 0;
    frame.atmosphere.on = false; /* set every frame, like the draws */
}

static void *grow(void *items, int *cap, size_t size) {
    *cap = *cap ? *cap * 2 : 64;
    void *grown = realloc(items, (size_t)*cap * size);
    if (!grown) abort(); /* out of memory while recording a frame: nothing sensible to continue with */
    return grown;
}

void fk_material_default(fk_material *m) {
    memset(m, 0, sizeof *m);
    m->base[0] = m->base[1] = m->base[2] = m->base[3] = 1;
    m->roughness = 0.6f;
    m->normal_scale = 1;
}

void fk_frame_draw_skinned(const fk_mesh *mesh, const float model[16], const fk_material *material, int bone_offset) {
    if (frame.ndraws == frame.draw_cap) frame.draws = grow(frame.draws, &frame.draw_cap, sizeof *frame.draws);
    fk_draw *d = &frame.draws[frame.ndraws++];
    d->mesh = mesh;
    memcpy(d->model, model, sizeof d->model);
    d->material = *material;
    d->bone_offset = bone_offset;
    d->slice = frame.slice;
    frame.triangles += mesh->count / 3;
}

void fk_frame_draw(const fk_mesh *mesh, const float model[16], const fk_material *material) {
    fk_frame_draw_skinned(mesh, model, material, -1);
}

int fk_frame_bones(const float *matrices, int count) {
    if (frame.nbones + count > FK_MAX_FRAME_BONES) return -1;
    while (frame.nbones + count > frame.bone_cap) frame.bones = grow(frame.bones, &frame.bone_cap, 16 * sizeof(float));
    memcpy(&frame.bones[frame.nbones * 16], matrices, (size_t)count * 16 * sizeof(float));
    frame.nbones += count;
    return frame.nbones - count;
}

void fk_frame_overlay(const fk_mesh *mesh, const float matrix[16]) {
    if (frame.noverlays == frame.overlay_cap) frame.overlays = grow(frame.overlays, &frame.overlay_cap, sizeof *frame.overlays);
    fk_overlay *o = &frame.overlays[frame.noverlays++];
    o->mesh = mesh;
    memcpy(o->matrix, matrix, sizeof o->matrix);
    o->first = o->count = 0;
}

static void sprite(float x, float y, float w, float h, int cell, const float color[4]) {
    if (frame.nsprites == frame.sprite_cap) frame.sprites = grow(frame.sprites, &frame.sprite_cap, sizeof *frame.sprites);
    fk_overlay *last = frame.noverlays ? &frame.overlays[frame.noverlays - 1] : NULL;
    if (!last || last->mesh || last->first + last->count != frame.nsprites) { /* start a new run */
        if (frame.noverlays == frame.overlay_cap) frame.overlays = grow(frame.overlays, &frame.overlay_cap, sizeof *frame.overlays);
        last = &frame.overlays[frame.noverlays++];
        last->mesh = NULL;
        last->first = frame.nsprites;
        last->count = 0;
    }
    /* the atlas is 16x8 cells of 8x8 pixels; cell 0 is solid, for rectangles */
    float u = (float)(cell % 16) / 16.0f, v = (float)(cell / 16) / 8.0f;
    fk_sprite *s = &frame.sprites[frame.nsprites++];
    *s = (fk_sprite){x, y, w, h, u, v, u + 1.0f / 16.0f, v + 1.0f / 8.0f, {color[0], color[1], color[2], color[3]}};
    last->count++;
}

void fk_frame_text(float x, float y, const char *text, const float color[4]) {
    float start = x;
    for (const unsigned char *c = (const unsigned char *)text; *c; c++) {
        if (*c == '\n') {
            x = start;
            y += 8;
            continue;
        }
        if (*c >= 0x80 && *c < 0xC0) continue; /* UTF-8 continuation byte: one '?' per character */
        if (*c != ' ') sprite(x, y, 8, 8, *c >= 33 && *c <= 126 ? *c : '?', color);
        x += 8;
    }
}

void fk_frame_rect(float x, float y, float w, float h, const float color[4]) { sprite(x, y, w, h, 0, color); }

float fk_halton(int index, int base) {
    float f = 1.0f, r = 0.0f;
    for (int i = index; i > 0; i /= base) {
        f /= (float)base;
        r += f * (float)(i % base);
    }
    return r - 0.5f;
}

void fk_frame_light(const fk_point_light *light) {
    if (frame.nlights < FK_MAX_LIGHTS) frame.lights[frame.nlights++] = *light;
}

void fk_gfx_settings_default(fk_gfx_settings *s) {
    *s = (fk_gfx_settings){480, 270, 1, 2, 1024, 8, 8, 4096, true, true, true, false, true};
    fk_gfx_set_image_size(s->width, s->height);
}

void fk_gfx_internal_size(const fk_gfx_settings *s, int win_w, int win_h, int *w, int *h) {
    *w = s->width, *h = s->height;
    if (!s->fill || win_w < s->width || win_h < s->height) return;
    int scale = win_h / s->height;
    *w = win_w / scale > 3840 ? 3840 : win_w / scale;
    *h = win_h / scale;
}

void fk_gfx_image_size(int *w, int *h) { *w = image_size[0], *h = image_size[1]; }
void fk_gfx_set_image_size(int w, int h) { image_size[0] = w, image_size[1] = h; }

fk_gfx_settings *fk_gfx_settings_current(void) { return &settings; }

const char *fk_gfx_settings_check(const fk_gfx_settings *s) {
    if (s->width < 64 || s->width > 3840) return "width";
    if (s->height < 64 || s->height > 2160) return "height";
    if (s->supersample != 1 && s->supersample != 2) return "supersample";
    if (s->shadow_cascades < 0 || s->shadow_cascades > 4) return "shadow_cascades";
    if (s->shadow_size < 256 || s->shadow_size > 4096) return "shadow_size";
    if (s->ao_samples < 0 || s->ao_samples > 16) return "ao_samples";
    if (s->max_lights < 0 || s->max_lights > FK_MAX_LIGHTS) return "max_lights";
    if (s->max_particles < 0 || s->max_particles > 65536) return "max_particles";
    return NULL;
}

void fk_gfx_upscale_rect(int win_w, int win_h, int img_w, int img_h, int rect[4]) {
    float sx = (float)win_w / (float)img_w, sy = (float)win_h / (float)img_h, s = fminf(sx, sy);
    if (s >= 1.0f) s = floorf(s); /* whole pixels when the window is large enough */
    rect[2] = (int)((float)img_w * s);
    rect[3] = (int)((float)img_h * s);
    rect[0] = (win_w - rect[2]) / 2;
    rect[1] = (win_h - rect[3]) / 2;
}

void fk_gfx_set_window(int win_w, int win_h, const int rect[4]) {
    window[0] = win_w, window[1] = win_h;
    memcpy(image, rect, sizeof image);
}

void fk_gfx_map_point(float *x, float *y) {
    *x = (*x * (float)window[0] - (float)image[0]) / (float)image[2];
    *y = (*y * (float)window[1] - (float)image[1]) / (float)image[3];
}

void fk_gfx_map_delta(float *dx, float *dy) {
    *dx *= (float)window[0] / (float)image[2];
    *dy *= (float)window[1] / (float)image[3];
}

void fk_mesh_normals(fk_vertex *v, int vertex_count, const uint32_t *idx, int index_count) {
    for (int i = 0; i < vertex_count; i++) memset(v[i].normal, 0, sizeof v[i].normal);
    for (int t = 0; t + 2 < index_count; t += 3) {
        const float *a = v[idx[t]].position, *b = v[idx[t + 1]].position, *c = v[idx[t + 2]].position;
        float u[3] = {b[0] - a[0], b[1] - a[1], b[2] - a[2]}, w[3] = {c[0] - a[0], c[1] - a[1], c[2] - a[2]};
        float n[3] = {u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]};
        for (int k = 0; k < 3; k++)
            for (int j = 0; j < 3; j++) v[idx[t + k]].normal[j] += n[j];
    }
    for (int i = 0; i < vertex_count; i++) {
        float *n = v[i].normal, len = sqrtf(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
        if (len > 0) n[0] /= len, n[1] /= len, n[2] /= len;
        else n[1] = 1; /* degenerate: point up rather than leave a zero normal */
    }
}

/* shortcut: per-triangle tangents averaged per vertex, not MikkTSpace; bake tangents into models that need exact normal maps */
void fk_mesh_tangents(fk_vertex *v, int vertex_count, const uint32_t *idx, int index_count) {
    float *bit = calloc((size_t)vertex_count * 3 + 1, sizeof(float));
    if (!bit) abort(); /* out of memory while loading: nothing sensible to continue with */
    for (int i = 0; i < vertex_count; i++) memset(v[i].tangent, 0, sizeof v[i].tangent);
    for (int t = 0; t + 2 < index_count; t += 3) {
        const fk_vertex *a = &v[idx[t]], *b = &v[idx[t + 1]], *c = &v[idx[t + 2]];
        float e1[3], e2[3], du1 = b->uv[0] - a->uv[0], dv1 = b->uv[1] - a->uv[1], du2 = c->uv[0] - a->uv[0], dv2 = c->uv[1] - a->uv[1];
        float det = du1 * dv2 - du2 * dv1, r = fabsf(det) > 1e-12f ? 1.0f / det : 0.0f;
        for (int k = 0; k < 3; k++) e1[k] = b->position[k] - a->position[k], e2[k] = c->position[k] - a->position[k];
        for (int j = 0; j < 3; j++)
            for (int k = 0; k < 3; k++) {
                v[idx[t + j]].tangent[k] += (e1[k] * dv2 - e2[k] * dv1) * r;
                bit[idx[t + j] * 3 + k] += (e2[k] * du1 - e1[k] * du2) * r;
            }
    }
    for (int i = 0; i < vertex_count; i++) {
        float *t = v[i].tangent, *n = v[i].normal, *b = &bit[i * 3];
        float d = n[0] * t[0] + n[1] * t[1] + n[2] * t[2];
        for (int k = 0; k < 3; k++) t[k] -= n[k] * d; /* Gram-Schmidt: perpendicular to the normal */
        float len = sqrtf(t[0] * t[0] + t[1] * t[1] + t[2] * t[2]);
        if (len > 1e-12f) t[0] /= len, t[1] /= len, t[2] /= len;
        else t[0] = 1, t[1] = t[2] = 0; /* no usable UVs */
        float c[3] = {n[1] * t[2] - n[2] * t[1], n[2] * t[0] - n[0] * t[2], n[0] * t[1] - n[1] * t[0]};
        t[3] = c[0] * b[0] + c[1] * b[1] + c[2] * b[2] < 0 ? -1.0f : 1.0f;
    }
    free(bit);
}
