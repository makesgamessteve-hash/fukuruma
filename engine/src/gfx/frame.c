#include "gfx/frame.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "core/mat4.h"

static fk_frame frame;
static fk_gfx_settings settings = {480, 270, 1, 2, 1024, 8, 8, true, true, true, false, true};
static int window[2] = {1, 1}, image[4] = {0, 0, 1, 1}, image_size[2] = {480, 270};

fk_frame *fk_frame_get(void) { return &frame; }

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
}

void fk_frame_begin(void) { frame.ndraws = frame.noverlays = frame.nlights = frame.nsprites = 0; }

static void *grow(void *items, int *cap, size_t size) {
    *cap = *cap ? *cap * 2 : 64;
    void *grown = realloc(items, (size_t)*cap * size);
    if (!grown) abort(); /* out of memory while recording a frame: nothing sensible to continue with */
    return grown;
}

void fk_frame_draw(const fk_mesh *mesh, const float model[16], const fk_material *material) {
    if (frame.ndraws == frame.draw_cap) frame.draws = grow(frame.draws, &frame.draw_cap, sizeof *frame.draws);
    fk_draw *d = &frame.draws[frame.ndraws++];
    d->mesh = mesh;
    memcpy(d->model, model, sizeof d->model);
    d->material = *material;
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
    *s = (fk_gfx_settings){480, 270, 1, 2, 1024, 8, 8, true, true, true, false, true};
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

void fk_mesh_normals(float *v, int vertex_count, const uint32_t *idx, int index_count) {
    for (int i = 0; i < vertex_count; i++) v[i * 9 + 6] = v[i * 9 + 7] = v[i * 9 + 8] = 0;
    for (int t = 0; t + 2 < index_count; t += 3) {
        const float *a = &v[idx[t] * 9], *b = &v[idx[t + 1] * 9], *c = &v[idx[t + 2] * 9];
        float u[3] = {b[0] - a[0], b[1] - a[1], b[2] - a[2]}, w[3] = {c[0] - a[0], c[1] - a[1], c[2] - a[2]};
        float n[3] = {u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]};
        for (int k = 0; k < 3; k++)
            for (int j = 0; j < 3; j++) v[idx[t + k] * 9 + 6 + j] += n[j];
    }
    for (int i = 0; i < vertex_count; i++) {
        float *n = &v[i * 9 + 6], len = sqrtf(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
        if (len > 0) n[0] /= len, n[1] /= len, n[2] /= len;
        else n[1] = 1; /* degenerate: point up rather than leave a zero normal */
    }
}
