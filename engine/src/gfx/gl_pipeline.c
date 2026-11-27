/* The render pipeline: shadows, G-buffer, ambient occlusion, lighting, bloom, exposure, post,
   supersample filter, overlay and the integer upscale to the window. */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "core/mat4.h"
#include "fx/particles.h"
#include "gfx/frame.h"
#include "gfx/gfx.h"
#include "gfx/gl.h"
#include "assets/vfs.h"
#include "gfx/shadow.h"
#include "platform/platform.h"
#include "stb_image.h"

#define BLOOM_LEVELS 4
#define LUM_W 64
#define LUM_H 32
#define LUM_LOD 6.0f /* the 1x1 mip level of the 64x32 luminance target */

enum { P_GBUFFER, P_SHADOW, P_SSAO, P_BLUR, P_LIGHT, P_BRIGHT, P_DOWN, P_UP, P_LUM, P_EXPOSURE, P_POST, P_OVERLAY, P_TAA, P_SPRITE,
       P_PARTICLE, P_ATMOSPHERE, P_COUNT };
static const char *const program_files[P_COUNT] = {"gbuffer", "shadow", "ssao",     "blur",     "lighting", "bloom", "bloom",
                                                   "bloom",   "luminance", "exposure", "post", "flat", "taa", "sprite",
                                                   "particle", "atmosphere"};
static const char *const program_defines[P_COUNT] = {
    "#define SCENE_MESH\n",
    "#define SCENE_MESH\n",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n#define PREFILTER\n",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n#define UP\n",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n",
    "",
    "#define FULLSCREEN\n",
    "",
    "",
    "#define FULLSCREEN\n",
};

static struct {
    bool hdr_supported;
    GLuint vao, white, font, sprite_vao, sprite_vbo, bones, particle_vao, particle_vbo, black_cube; /* survive reconfiguration */
    GLuint programs[P_COUNT];
    char renderer[128];
    GLuint history[2], fb_history[2]; /* temporal anti-aliasing */
    int history_index, frame_index;
    bool history_valid;
    float prev_view_proj[16];
    int w, h; /* internal image size */
    GLuint g_base, g_normal, g_emission, g_depth, fb_gbuffer;
    GLuint shadow, fb_shadow;
    GLuint ao[2], fb_ao[2];
    GLuint light, fb_light, air, fb_air; /* air: the lit image seen through the atmosphere */
    GLuint bloom[BLOOM_LEVELS], fb_bloom[BLOOM_LEVELS];
    int bloom_w[BLOOM_LEVELS], bloom_h[BLOOM_LEVELS];
    GLuint lum, fb_lum;
    GLuint exposure[2], fb_exposure[2];
    int exposure_index;
    bool exposure_valid;
    GLuint final_ss, fb_final_ss, final, fb_final;
    fk_gfx_settings s; /* applied settings; s.hdr is what is actually used */
    int sw, sh;        /* supersampled size */
} R;

static GLuint texture(GLenum internal, GLenum format, GLenum type, int w, int h, GLint filter) {
    GLuint t;
    gl.GenTextures(1, &t);
    gl.BindTexture(GL_TEXTURE_2D, t);
    gl.TexImage2D(GL_TEXTURE_2D, 0, (GLint)internal, w, h, 0, format, type, NULL);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter == GL_LINEAR_MIPMAP_LINEAR ? GL_LINEAR : filter);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    return t;
}

static bool complete = true; /* false when a framebuffer could not be completed */

static GLuint framebuffer(int n, const GLuint *colors, GLuint depth) {
    GLuint fb;
    GLenum buffers[3] = {GL_NONE, GL_NONE, GL_NONE};
    gl.GenFramebuffers(1, &fb);
    gl.BindFramebuffer(GL_FRAMEBUFFER, fb);
    for (int i = 0; i < n; i++) {
        buffers[i] = GL_COLOR_ATTACHMENT0 + (GLenum)i;
        gl.FramebufferTexture2D(GL_FRAMEBUFFER, buffers[i], GL_TEXTURE_2D, colors[i], 0);
    }
    if (depth) gl.FramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depth, 0);
    gl.DrawBuffers(n ? n : 1, buffers);
    if (gl.CheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) complete = false;
    return fb;
}

static void release(void) {
    for (int i = 0; i < P_COUNT; i++)
        if (R.programs[i]) gl.DeleteProgram(R.programs[i]);
    GLuint textures[] = {R.g_base,      R.g_normal, R.g_emission,  R.g_depth,     R.shadow,   R.ao[0],    R.ao[1],
                         R.light,       R.bloom[0], R.bloom[1],    R.bloom[2],    R.bloom[3], R.lum,      R.exposure[0],
                         R.exposure[1], R.final_ss, R.final, R.history[0], R.history[1], R.air};
    GLuint fbs[] = {R.fb_gbuffer, R.fb_shadow,   R.fb_ao[0],       R.fb_ao[1],       R.fb_light,    R.fb_bloom[0],
                    R.fb_bloom[1], R.fb_bloom[2], R.fb_bloom[3],    R.fb_lum,         R.fb_exposure[0],
                    R.fb_exposure[1], R.fb_final_ss, R.fb_final, R.fb_history[0], R.fb_history[1], R.fb_air};
    gl.DeleteTextures((GLsizei)(sizeof textures / sizeof *textures), textures);
    gl.DeleteFramebuffers((GLsizei)(sizeof fbs / sizeof *fbs), fbs);
    bool hdr_supported = R.hdr_supported;
    GLuint vao = R.vao, white = R.white, font = R.font, sprite_vao = R.sprite_vao, sprite_vbo = R.sprite_vbo, bones = R.bones;
    GLuint particle_vao = R.particle_vao, particle_vbo = R.particle_vbo, black_cube = R.black_cube;
    char renderer[sizeof R.renderer];
    memcpy(renderer, R.renderer, sizeof renderer);
    memset(&R, 0, sizeof R);
    R.hdr_supported = hdr_supported, R.vao = vao, R.white = white, R.font = font;
    R.sprite_vao = sprite_vao, R.sprite_vbo = sprite_vbo, R.bones = bones;
    R.particle_vao = particle_vao, R.particle_vbo = particle_vbo, R.black_cube = black_cube;
    memcpy(R.renderer, renderer, sizeof renderer);
}

bool fk_gfx_configure(void) {
    fk_gfx_settings *current = fk_gfx_settings_current();
    if (!R.hdr_supported) current->hdr = false; /* no float render targets: the LDR fallback */
    release();
    R.s = *current;
    int w, h;
    fk_gfx_image_size(&w, &h);
    R.w = w, R.h = h;
    R.sw = w * R.s.supersample, R.sh = h * R.s.supersample;

    char defines[256], all[512];
    snprintf(defines, sizeof defines, "#define SHADOW_CASCADES %d\n#define SHADOW_SIZE %d\n#define AO_SAMPLES %d\n#define MAX_LIGHTS %d\n%s%s%s%s",
             R.s.shadow_cascades, R.s.shadow_size, R.s.ao_samples, R.s.max_lights, R.s.hdr ? "#define HDR\n" : "",
             R.s.hdr && R.s.bloom ? "#define BLOOM\n" : "", R.s.dither ? "#define DITHER\n" : "", R.s.taa ? "#define TAA\n" : "");
    bool ok = true;
    for (int i = 0; i < P_COUNT; i++) {
        snprintf(all, sizeof all, "%s%s", defines, program_defines[i]);
        R.programs[i] = fk_gl_program(program_files[i], all);
        ok = ok && R.programs[i];
    }
    if (!ok) return false;

    complete = true;
    R.g_base = texture(GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, R.sw, R.sh, GL_NEAREST);
    R.g_normal = texture(GL_RGB10_A2, GL_RGBA, GL_UNSIGNED_INT_2_10_10_10_REV, R.sw, R.sh, GL_NEAREST);
    R.g_emission = texture(GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, R.sw, R.sh, GL_NEAREST);
    R.g_depth = texture(GL_DEPTH_COMPONENT24, GL_DEPTH_COMPONENT, GL_UNSIGNED_INT, R.sw, R.sh, GL_NEAREST);
    R.fb_gbuffer = framebuffer(3, (GLuint[]){R.g_base, R.g_normal, R.g_emission}, R.g_depth);
    if (R.s.shadow_cascades) {
        gl.GenTextures(1, &R.shadow);
        gl.BindTexture(GL_TEXTURE_2D_ARRAY, R.shadow);
        gl.TexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_DEPTH_COMPONENT24, R.s.shadow_size, R.s.shadow_size, R.s.shadow_cascades, 0,
                      GL_DEPTH_COMPONENT, GL_UNSIGNED_INT, NULL);
        gl.TexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_LINEAR); /* hardware 2x2 PCF */
        gl.TexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        gl.TexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        gl.TexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        gl.TexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_REF_TO_TEXTURE);
        gl.TexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_COMPARE_FUNC, GL_LEQUAL);
        gl.GenFramebuffers(1, &R.fb_shadow);
        gl.BindFramebuffer(GL_FRAMEBUFFER, R.fb_shadow);
        gl.FramebufferTextureLayer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, R.shadow, 0, 0);
        GLenum none = GL_NONE;
        gl.DrawBuffers(1, &none);
        gl.ReadBuffer(GL_NONE);
        if (gl.CheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) complete = false;
    }
    if (R.s.ao_samples)
        for (int i = 0; i < 2; i++) {
            R.ao[i] = texture(GL_R8, GL_RED, GL_UNSIGNED_BYTE, R.sw, R.sh, GL_NEAREST);
            R.fb_ao[i] = framebuffer(1, &R.ao[i], 0);
        }
    R.light = R.s.hdr ? texture(GL_RGBA16F, GL_RGBA, GL_HALF_FLOAT, R.sw, R.sh, GL_LINEAR)
                      : texture(GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, R.sw, R.sh, GL_LINEAR);
    R.fb_light = framebuffer(1, &R.light, 0);
    R.air = R.s.hdr ? texture(GL_RGBA16F, GL_RGBA, GL_HALF_FLOAT, R.sw, R.sh, GL_LINEAR)
                    : texture(GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, R.sw, R.sh, GL_LINEAR);
    R.fb_air = framebuffer(1, &R.air, 0);
    if (R.s.taa)
        for (int i = 0; i < 2; i++) {
            R.history[i] = R.s.hdr ? texture(GL_RGBA16F, GL_RGBA, GL_HALF_FLOAT, R.sw, R.sh, GL_LINEAR)
                                   : texture(GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, R.sw, R.sh, GL_LINEAR);
            R.fb_history[i] = framebuffer(1, &R.history[i], 0);
        }
    if (R.s.hdr) {
        for (int i = 0; R.s.bloom && i < BLOOM_LEVELS; i++) {
            R.bloom_w[i] = R.sw >> (i + 1) > 0 ? R.sw >> (i + 1) : 1;
            R.bloom_h[i] = R.sh >> (i + 1) > 0 ? R.sh >> (i + 1) : 1;
            R.bloom[i] = texture(GL_RGBA16F, GL_RGBA, GL_HALF_FLOAT, R.bloom_w[i], R.bloom_h[i], GL_LINEAR);
            R.fb_bloom[i] = framebuffer(1, &R.bloom[i], 0);
        }
        R.lum = texture(GL_R16F, GL_RED, GL_HALF_FLOAT, LUM_W, LUM_H, GL_LINEAR_MIPMAP_LINEAR);
        gl.GenerateMipmap(GL_TEXTURE_2D);
        R.fb_lum = framebuffer(1, &R.lum, 0);
        for (int i = 0; i < 2; i++) {
            R.exposure[i] = texture(GL_R16F, GL_RED, GL_HALF_FLOAT, 1, 1, GL_NEAREST);
            R.fb_exposure[i] = framebuffer(1, &R.exposure[i], 0);
        }
    }
    if (R.s.supersample > 1) {
        R.final_ss = texture(GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, R.sw, R.sh, GL_LINEAR);
        R.fb_final_ss = framebuffer(1, &R.final_ss, 0);
    }
    R.final = texture(GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, w, h, GL_NEAREST);
    R.fb_final = framebuffer(1, &R.final, 0);
    if (!complete) fk_log("a render target could not be created");
    return complete;
}

bool fk_gfx_init(void) {
    fk_gl_load();
#ifdef __EMSCRIPTEN__
    R.hdr_supported = fk_platform_gl_extension("GL_EXT_color_buffer_float");
#else
    R.hdr_supported = true; /* float render targets are core in OpenGL 3.3 */
#endif
    gl.GenVertexArrays(1, &R.vao); /* empty: full-screen passes make their triangle from gl_VertexID */
    const unsigned char white[4] = {255, 255, 255, 255};
    gl.GenTextures(1, &R.white);
    gl.BindTexture(GL_TEXTURE_2D, R.white);
    gl.TexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, white);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    static const float identity[16] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
    gl.GenTextures(1, &R.bones); /* starts with one identity bone, so it is complete before any skinned draw */
    gl.BindTexture(GL_TEXTURE_2D, R.bones);
    gl.TexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, 4, 1, 0, GL_RGBA, GL_FLOAT, identity);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    gl.GenTextures(1, &R.black_cube); /* the sky when there is none */
    gl.BindTexture(GL_TEXTURE_CUBE_MAP, R.black_cube);
    const unsigned char black[4] = {0, 0, 0, 255};
    for (int f = 0; f < 6; f++) gl.TexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + (GLenum)f, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, black);
    gl.TexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    const char *renderer = (const char *)gl.GetString(GL_RENDERER);
    snprintf(R.renderer, sizeof R.renderer, "%s", renderer ? renderer : "unknown");

    /* The 8x8 font atlas for text and rectangles. */
    char path[1024];
    size_t size;
    unsigned char *png = fk_vfs_read("fonts/font8x8.png", &size);
    int fw = 0, fh = 0, n;
    unsigned char *pixels = png ? stbi_load_from_memory(png, (int)size, &fw, &fh, &n, 4) : NULL;
    fk_platform_free(png);
    if (!pixels) {
        fk_log("cannot load the font %s", fk_vfs_path("fonts/font8x8.png", path, sizeof path));
        return false;
    }
    gl.GenTextures(1, &R.font);
    gl.BindTexture(GL_TEXTURE_2D, R.font);
    gl.TexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, fw, fh, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    stbi_image_free(pixels);
    gl.GenVertexArrays(1, &R.sprite_vao);
    gl.GenBuffers(1, &R.sprite_vbo);
    gl.BindVertexArray(R.sprite_vao);
    gl.BindBuffer(GL_ARRAY_BUFFER, R.sprite_vbo);
    for (GLuint a = 0; a < 2; a++) { /* x, y, u, v; r, g, b, a */
        gl.VertexAttribPointer(a, 4, GL_FLOAT, GL_FALSE, 8 * (GLsizei)sizeof(float), (const void *)(a * 4 * sizeof(float)));
        gl.EnableVertexAttribArray(a);
    }
    gl.GenVertexArrays(1, &R.particle_vao);
    gl.GenBuffers(1, &R.particle_vbo);
    gl.BindVertexArray(R.particle_vao);
    gl.BindBuffer(GL_ARRAY_BUFFER, R.particle_vbo);
    static const struct {
        GLuint location;
        int size, offset;
    } particle_attributes[] = {{0, 3, 0}, {3, 2, 3}, {1, 4, 5}}; /* position, uv, colour (rgba) */
    for (int a = 0; a < 3; a++) {
        gl.VertexAttribPointer(particle_attributes[a].location, particle_attributes[a].size, GL_FLOAT, GL_FALSE,
                               9 * (GLsizei)sizeof(float), (const void *)(particle_attributes[a].offset * sizeof(float)));
        gl.EnableVertexAttribArray(particle_attributes[a].location);
    }
    gl.BindVertexArray(0);
    return fk_gfx_configure();
}

const char *fk_gfx_renderer(void) { return R.renderer; }

void fk_gfx_shutdown(void) {
    release();
    GLuint textures[4] = {R.white, R.font, R.bones, R.black_cube}, vaos[3] = {R.vao, R.sprite_vao, R.particle_vao};
    GLuint buffers[2] = {R.sprite_vbo, R.particle_vbo};
    gl.DeleteTextures(4, textures);
    gl.DeleteVertexArrays(3, vaos);
    gl.DeleteBuffers(2, buffers);
    memset(&R, 0, sizeof R);
}

static GLuint use(int p) {
    gl.UseProgram(R.programs[p]);
    return R.programs[p];
}

static void sampler(GLuint program, const char *name, int unit, GLenum target, GLuint tex) {
    gl.ActiveTexture(GL_TEXTURE0 + (GLenum)unit);
    gl.BindTexture(target, tex);
    gl.Uniform1i(gl.GetUniformLocation(program, name), unit);
}

#define LOC(name) gl.GetUniformLocation(program, name)

static void target(GLuint fb, int w, int h) {
    gl.BindFramebuffer(GL_FRAMEBUFFER, fb);
    gl.Viewport(0, 0, w, h);
}

static void fullscreen(void) { gl.DrawArrays(GL_TRIANGLES, 0, 3); }

/* Draws the meshes of the slices in the mask (bit i: slice i). */
static void draw_meshes(GLuint program, bool materials, unsigned slices) {
    fk_frame *f = fk_frame_get();
    sampler(program, "u_bones", materials ? 4 : 0, GL_TEXTURE_2D, R.bones);
    for (int i = 0; i < f->ndraws; i++) {
        const fk_draw *d = &f->draws[i];
        if (!(slices & 1u << d->slice)) continue;
        gl.UniformMatrix4fv(LOC("u_model"), 1, GL_FALSE, d->model);
        gl.Uniform1i(LOC("u_bone_offset"), d->bone_offset);
        if (materials) {
            const fk_material *m = &d->material;
            gl.Uniform4fv(LOC("u_base"), 1, m->base);
            gl.Uniform1f(LOC("u_roughness"), m->roughness);
            gl.Uniform1f(LOC("u_metalness"), m->metalness);
            gl.Uniform3fv(LOC("u_emission"), 1, m->emission);
            bool normal_map = m->normal_tex && m->normal_tex->id;
            gl.Uniform1f(LOC("u_normal_scale"), normal_map ? m->normal_scale : 0.0f); /* 0: no normal map */
            gl.Uniform1f(LOC("u_one_sided"), m->one_sided ? 1.0f : 0.0f);
            gl.Uniform1f(LOC("u_emissive_colors"), m->emissive_colors ? 1.0f : 0.0f);
            gl.Uniform1f(LOC("u_clouds"), m->clouds);
            const fk_texture *textures[4] = {m->base_tex, m->metal_rough_tex, m->normal_tex, m->emission_tex};
            static const char *names[4] = {"u_base_tex", "u_metal_rough_tex", "u_normal_tex", "u_emission_tex"};
            for (int t = 0; t < 4; t++) sampler(program, names[t], t, GL_TEXTURE_2D, textures[t] && textures[t]->id ? textures[t]->id : R.white);
        }
        gl.BindVertexArray(d->mesh->vao);
        gl.DrawElements(GL_TRIANGLES, d->mesh->count, GL_UNSIGNED_INT, (const void *)0);
    }
}

/* The slices' projections (with this frame's TAA jitter) and their inverses. */
static float slice_proj[FK_SLICE_COUNT][16], slice_inv[FK_SLICE_COUNT][16];

/* What the shaders need to find a pixel's view-space position from its depth (see view_position in common.glsl). */
static void slice_uniforms(GLuint program) {
    gl.Uniform4fv(LOC("u_slice_lo"), 1, FK_SLICE_DEPTH);
    gl.Uniform4fv(LOC("u_slice_hi"), 1, FK_SLICE_DEPTH + 1);
    gl.UniformMatrix4fv(LOC("u_slice_inv_proj"), FK_SLICE_COUNT, GL_FALSE, &slice_inv[0][0]);
}

static void depth_range(int slice) { gl.DepthRange(FK_SLICE_DEPTH[slice], FK_SLICE_DEPTH[slice + 1]); }

static float particle_depth[65536];
static int by_depth(const void *a, const void *b) { /* far ones first */
    float da = particle_depth[*(const int *)a], db = particle_depth[*(const int *)b];
    return (da < db) - (da > db);
}

/* Camera-facing quads: lit, alpha-blended dust sorted back to front, then glowing particles added on top.
   Both test against the G-buffer depth in the shader and fade softly where they meet surfaces. */
static void draw_particles(const float view_proj[16], const fk_frame *f) {
    int n = fk_particles_count();
    if (!n) return;
    const fk_particle *list = fk_particles_list();
    static float *vertices;
    static int *order, capacity;
    if (n > capacity) {
        capacity = n;
        float *v = realloc(vertices, (size_t)capacity * 6 * 9 * sizeof(float));
        int *o = realloc(order, (size_t)capacity * sizeof(int));
        if (!v || !o) abort(); /* out of memory while drawing: nothing sensible to continue with */
        vertices = v, order = o;
    }
    const float *view = f->view;
    float right[3] = {view[0], view[4], view[8]}, up[3] = {view[1], view[5], view[9]};
    int dust = 0, glow = n;
    for (int i = 0; i < n; i++) { /* dust from the front, glow from the back of the order */
        particle_depth[i] = -(view[2] * list[i].position[0] + view[6] * list[i].position[1] + view[10] * list[i].position[2] + view[14]);
        if (list[i].glow) order[--glow] = i;
        else order[dust++] = i;
    }
    qsort(order, (size_t)dust, sizeof *order, by_depth);
    static const float corners[6][2] = {{-1, -1}, {1, -1}, {1, 1}, {-1, -1}, {1, 1}, {-1, 1}};
    for (int q = 0; q < n; q++) {
        const fk_particle *p = &list[order[q]];
        float t = p->age / p->life, half = 0.5f * (p->size + (p->size_end - p->size) * t), color[4];
        for (int k = 0; k < 4; k++) color[k] = p->color[k] + (p->color_end[k] - p->color[k]) * t;
        for (int c = 0; c < 6; c++) {
            float *v = &vertices[(q * 6 + c) * 9];
            for (int k = 0; k < 3; k++) v[k] = p->position[k] + (right[k] * corners[c][0] + up[k] * corners[c][1]) * half;
            v[3] = corners[c][0] * 0.5f + 0.5f, v[4] = corners[c][1] * 0.5f + 0.5f;
            memcpy(&v[5], color, sizeof color);
        }
    }
    gl.BindBuffer(GL_ARRAY_BUFFER, R.particle_vbo);
    gl.BufferData(GL_ARRAY_BUFFER, (GLsizeiptr)n * 6 * 9 * (GLsizeiptr)sizeof(float), vertices, GL_STREAM_DRAW);
    target(R.fb_light, R.sw, R.sh);
    GLuint program = use(P_PARTICLE);
    gl.UniformMatrix4fv(LOC("u_view_proj"), 1, GL_FALSE, view_proj);
    sampler(program, "u_depth", 0, GL_TEXTURE_2D, R.g_depth);
    slice_uniforms(program);
    depth_range(FK_SLICE_LOCAL); /* particles are in the local slice: gl_FragCoord.z lands in its range */
    float sun_up = f->sun_dir[1] > 0 ? f->sun_dir[1] : 0, light[3];
    for (int k = 0; k < 3; k++) light[k] = 0.5f * (f->sky[k] + f->ground[k]) + 0.3f * sun_up * f->sun_color[k];
    gl.Uniform3fv(LOC("u_light"), 1, light);
    gl.BindVertexArray(R.particle_vao);
    gl.Enable(GL_BLEND);
    if (dust) {
        gl.BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        gl.Uniform1f(LOC("u_glow"), 0.0f);
        gl.DrawArrays(GL_TRIANGLES, 0, dust * 6);
    }
    if (glow < n) {
        gl.BlendFunc(GL_ONE, GL_ONE);
        gl.Uniform1f(LOC("u_glow"), 1.0f);
        gl.DrawArrays(GL_TRIANGLES, glow * 6, (n - glow) * 6);
    }
    gl.Disable(GL_BLEND);
    gl.DepthRange(0, 1);
    gl.BindVertexArray(R.vao);
}

void fk_gfx_render(double dt, int window_w, int window_h) {
    int want_w, want_h;
    fk_gfx_internal_size(fk_gfx_settings_current(), window_w, window_h, &want_w, &want_h);
    if (want_w != R.w || want_h != R.h) { /* the window changed shape: new targets */
        fk_gfx_set_image_size(want_w, want_h);
        fk_gfx_configure();
    }
    fk_frame *f = fk_frame_get();
    const float *p = f->projection;
    bool perspective = p[11] == -1.0f;
    /* TAA: a different sub-pixel offset every frame (8 Halton points), for everything but the shadows. */
    float proj[16], plain_vp[16], plain_inv_vp[16], view_proj[16], inv_view[16];
    memcpy(proj, p, sizeof proj);
    if (R.s.taa) {
        int k = R.frame_index % 8 + 1;
        proj[perspective ? 8 : 12] += fk_halton(k, 2) * 2.0f / (float)R.sw;
        proj[perspective ? 9 : 13] += fk_halton(k, 3) * 2.0f / (float)R.sh;
    }
    R.frame_index++;
    fk_mat4_mul(plain_vp, f->projection, f->view);
    fk_mat4_mul(view_proj, proj, f->view);
    if (!fk_mat4_inverse(plain_inv_vp, plain_vp)) fk_mat4_identity(plain_inv_vp);
    if (!fk_mat4_inverse(inv_view, f->view)) fk_mat4_identity(inv_view);
    unsigned used = 0;
    for (int i = 0; i < f->ndraws; i++) used |= 1u << f->draws[i].slice;
    for (int sl = 0; sl < FK_SLICE_COUNT; sl++) {
        fk_frame_slice_projection(f, sl, slice_proj[sl]);
        slice_proj[sl][perspective ? 8 : 12] += proj[perspective ? 8 : 12] - p[perspective ? 8 : 12]; /* the jitter */
        slice_proj[sl][perspective ? 9 : 13] += proj[perspective ? 9 : 13] - p[perspective ? 9 : 13];
        if (!fk_mat4_inverse(slice_inv[sl], slice_proj[sl])) fk_mat4_identity(slice_inv[sl]);
    }
    float z_near = perspective ? p[14] / (p[10] - 1.0f) : 0.1f, z_far = perspective ? p[14] / (p[10] + 1.0f) : 100.0f;
    GLuint program;

    /* 0. Bone matrices of the skinned draws: one row of four RGBA32F texels (the columns) per bone. */
    if (f->nbones) {
        gl.BindTexture(GL_TEXTURE_2D, R.bones);
        gl.TexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, 4, f->nbones, 0, GL_RGBA, GL_FLOAT, f->bones);
    }

    /* 1. Star shadows, one cascade per texture layer. */
    fk_cascade cascades[FK_MAX_CASCADES];
    float cascade_vp[FK_MAX_CASCADES * 16], splits[4] = {0, 0, 0, 0}, texels[4] = {0, 0, 0, 0};
    int nc = R.s.shadow_cascades;
    gl.Enable(GL_DEPTH_TEST);
    if (nc) {
        target(R.fb_shadow, R.s.shadow_size, R.s.shadow_size);
        gl.Enable(GL_POLYGON_OFFSET_FILL);
        gl.PolygonOffset(2.0f, 4.0f);
        program = use(P_SHADOW);
        for (int c = 0; c < nc; c++) {
            float d0 = c ? cascades[c - 1].split : z_near;
            fk_shadow_cascade(&cascades[c], plain_inv_vp, z_near, z_far, d0, fk_shadow_split(c, nc, z_near, z_far), f->sun_dir, R.s.shadow_size);
            memcpy(&cascade_vp[c * 16], cascades[c].view_proj, sizeof cascades[c].view_proj);
            splits[c] = cascades[c].split;
            texels[c] = cascades[c].texel;
            gl.FramebufferTextureLayer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, R.shadow, 0, c);
            gl.Clear(GL_DEPTH_BUFFER_BIT);
            gl.UniformMatrix4fv(LOC("u_view_proj"), 1, GL_FALSE, cascades[c].view_proj);
            draw_meshes(program, false, 1u << FK_SLICE_NEAR | 1u << FK_SLICE_LOCAL); /* far slices cast no shadows here */
        }
        gl.Disable(GL_POLYGON_OFFSET_FILL);
    }

    /* 2. G-buffer. */
    target(R.fb_gbuffer, R.sw, R.sh);
    gl.ClearColor(0, 0, 0, 0);
    gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    program = use(P_GBUFFER);
    for (int sl = 0; sl < FK_SLICE_COUNT; sl++) { /* each slice in its own part of the depth buffer */
        if (!(used & 1u << sl)) continue;
        float vp[16];
        fk_mat4_mul(vp, slice_proj[sl], f->view);
        depth_range(sl);
        gl.UniformMatrix4fv(LOC("u_view_proj"), 1, GL_FALSE, vp);
        draw_meshes(program, true, 1u << sl);
    }
    gl.DepthRange(0, 1);
    gl.Disable(GL_DEPTH_TEST);
    gl.BindVertexArray(R.vao);

    /* 3. Ambient occlusion, then a 4x4 blur. */
    GLuint ao = R.white;
    if (R.s.ao_samples) {
        target(R.fb_ao[0], R.sw, R.sh);
        program = use(P_SSAO);
        sampler(program, "u_depth", 0, GL_TEXTURE_2D, R.g_depth);
        sampler(program, "u_normal", 1, GL_TEXTURE_2D, R.g_normal);
        slice_uniforms(program);
        gl.UniformMatrix4fv(LOC("u_proj"), 1, GL_FALSE, proj);
        gl.UniformMatrix4fv(LOC("u_view"), 1, GL_FALSE, f->view);
        fullscreen();
        target(R.fb_ao[1], R.sw, R.sh);
        program = use(P_BLUR);
        sampler(program, "u_input", 0, GL_TEXTURE_2D, R.ao[0]);
        gl.Uniform2f(LOC("u_texel"), 1.0f / (float)R.sw, 1.0f / (float)R.sh);
        fullscreen();
        ao = R.ao[1];
    }

    /* 4. Lighting. */
    target(R.fb_light, R.sw, R.sh);
    program = use(P_LIGHT);
    sampler(program, "u_base", 0, GL_TEXTURE_2D, R.g_base);
    sampler(program, "u_normal", 1, GL_TEXTURE_2D, R.g_normal);
    sampler(program, "u_emission", 2, GL_TEXTURE_2D, R.g_emission);
    sampler(program, "u_depth", 3, GL_TEXTURE_2D, R.g_depth);
    sampler(program, "u_ao", 4, GL_TEXTURE_2D, ao);
    sampler(program, "u_shadow", 5, GL_TEXTURE_2D_ARRAY, R.shadow);
    sampler(program, "u_sky_map", 6, GL_TEXTURE_CUBE_MAP, f->sky_map && f->sky_map->id ? f->sky_map->id : R.black_cube);
    gl.Uniform1f(LOC("u_sky_strength"), f->sky_strength);
    gl.UniformMatrix3fv(LOC("u_sky_rotation"), 1, GL_FALSE, f->sky_rotation);
    slice_uniforms(program);
    gl.UniformMatrix4fv(LOC("u_inv_view"), 1, GL_FALSE, inv_view);
    gl.UniformMatrix4fv(LOC("u_view"), 1, GL_FALSE, f->view);
    if (nc) gl.UniformMatrix4fv(LOC("u_cascade"), nc, GL_FALSE, cascade_vp);
    gl.Uniform4fv(LOC("u_splits"), 1, splits);
    gl.Uniform4fv(LOC("u_texels"), 1, texels);
    gl.Uniform3fv(LOC("u_camera"), 1, &inv_view[12]);
    gl.Uniform3fv(LOC("u_sun_dir"), 1, f->sun_dir);
    gl.Uniform3fv(LOC("u_sun_color"), 1, f->sun_color);
    gl.Uniform3fv(LOC("u_sun2_dir"), 1, f->sun2_dir);
    gl.Uniform3fv(LOC("u_sun2_color"), 1, f->sun2_color);
    gl.Uniform3fv(LOC("u_sky"), 1, f->sky);
    gl.Uniform3fv(LOC("u_ground"), 1, f->ground);
    gl.Uniform3fv(LOC("u_background"), 1, f->background);
    gl.Uniform1f(LOC("u_exposure_bias"), exp2f(f->exposure));
    int nlights = f->nlights < R.s.max_lights ? f->nlights : R.s.max_lights;
    float positions[FK_MAX_LIGHTS * 4], colors[FK_MAX_LIGHTS * 4];
    for (int i = 0; i < nlights; i++) {
        memcpy(&positions[i * 4], f->lights[i].position, 3 * sizeof(float));
        positions[i * 4 + 3] = f->lights[i].radius;
        memcpy(&colors[i * 4], f->lights[i].color, 3 * sizeof(float));
        colors[i * 4 + 3] = 0;
    }
    gl.Uniform1i(LOC("u_nlights"), nlights);
    if (nlights) {
        gl.Uniform4fv(LOC("u_light_pos"), nlights, positions);
        gl.Uniform4fv(LOC("u_light_color"), nlights, colors);
    }
    fullscreen();

    /* 4a. Particles: a forward pass into the lit image. */
    draw_particles(view_proj, f);

    /* 4b. TAA: blend with the reprojected, neighbourhood-clamped history. */
    GLuint scene = R.light;
    const fk_atmosphere *a = &f->atmosphere;
    if (a->on) { /* 4b. The air between the camera and everything */
        target(R.fb_air, R.sw, R.sh);
        program = use(P_ATMOSPHERE);
        sampler(program, "u_scene", 0, GL_TEXTURE_2D, R.light);
        sampler(program, "u_depth", 1, GL_TEXTURE_2D, R.g_depth);
        slice_uniforms(program);
        gl.UniformMatrix4fv(LOC("u_inv_view"), 1, GL_FALSE, inv_view);
        gl.Uniform3fv(LOC("u_centre"), 1, a->centre);
        gl.Uniform1f(LOC("u_radius"), a->radius);
        gl.Uniform1f(LOC("u_top"), a->top);
        gl.Uniform1f(LOC("u_height"), a->height);
        gl.Uniform3fv(LOC("u_rayleigh"), 1, a->rayleigh);
        gl.Uniform1f(LOC("u_mie"), a->mie);
        gl.Uniform3fv(LOC("u_absorb"), 1, a->absorb);
        gl.Uniform3fv(LOC("u_sun_dir"), 1, f->sun_dir);
        gl.Uniform3fv(LOC("u_sun_color"), 1, f->sun_color);
        float ground[3];
        for (int k = 0; k < 3; k++) ground[k] = a->ground[k] * f->sun_color[k] * 0.3183099f; /* albedo / pi */
        gl.Uniform3fv(LOC("u_ground"), 1, ground);
        fullscreen();
        scene = R.air;
    }
    if (R.s.taa) {
        int next = 1 - R.history_index;
        target(R.fb_history[next], R.sw, R.sh);
        program = use(P_TAA);
        sampler(program, "u_current", 0, GL_TEXTURE_2D, scene);
        sampler(program, "u_history", 1, GL_TEXTURE_2D, R.history[R.history_index]);
        sampler(program, "u_depth", 2, GL_TEXTURE_2D, R.g_depth);
        slice_uniforms(program);
        gl.UniformMatrix4fv(LOC("u_inv_view"), 1, GL_FALSE, inv_view);
        gl.UniformMatrix4fv(LOC("u_prev_view_proj"), 1, GL_FALSE, R.prev_view_proj);
        gl.Uniform2f(LOC("u_texel"), 1.0f / (float)R.sw, 1.0f / (float)R.sh);
        gl.Uniform1f(LOC("u_valid"), R.history_valid ? 1.0f : 0.0f);
        fullscreen();
        R.history_index = next;
        R.history_valid = true;
        scene = R.history[next];
    }
    memcpy(R.prev_view_proj, plain_vp, sizeof plain_vp);

    /* 5. HDR: average luminance, eye adaptation, bloom. */
    if (R.s.hdr) {
        target(R.fb_lum, LUM_W, LUM_H);
        program = use(P_LUM);
        sampler(program, "u_input", 0, GL_TEXTURE_2D, scene);
        sampler(program, "u_depth", 1, GL_TEXTURE_2D, R.g_depth);
        slice_uniforms(program);
        fullscreen();
        gl.BindTexture(GL_TEXTURE_2D, R.lum);
        gl.GenerateMipmap(GL_TEXTURE_2D);
        int next = 1 - R.exposure_index;
        target(R.fb_exposure[next], 1, 1);
        program = use(P_EXPOSURE);
        sampler(program, "u_luminance", 0, GL_TEXTURE_2D, R.lum);
        sampler(program, "u_previous", 1, GL_TEXTURE_2D, R.exposure[R.exposure_index]);
        gl.Uniform1f(LOC("u_lod"), LUM_LOD);
        gl.Uniform1f(LOC("u_adapt"), R.exposure_valid ? 1.0f - expf(-(float)dt / 0.7f) : 1.0f);
        gl.Uniform1f(LOC("u_bias"), exp2f(f->exposure));
        fullscreen();
        R.exposure_index = next;
        R.exposure_valid = true;
        if (R.s.bloom) {
            for (int i = 0; i < BLOOM_LEVELS; i++) {
                target(R.fb_bloom[i], R.bloom_w[i], R.bloom_h[i]);
                program = use(i ? P_DOWN : P_BRIGHT);
                sampler(program, "u_input", 0, GL_TEXTURE_2D, i ? R.bloom[i - 1] : scene);
                sampler(program, "u_exposure", 1, GL_TEXTURE_2D, R.exposure[R.exposure_index]);
                gl.Uniform2f(LOC("u_texel"), 1.0f / (float)(i ? R.bloom_w[i - 1] : R.sw), 1.0f / (float)(i ? R.bloom_h[i - 1] : R.sh));
                fullscreen();
            }
            gl.Enable(GL_BLEND);
            gl.BlendFunc(GL_ONE, GL_ONE);
            program = use(P_UP);
            for (int i = BLOOM_LEVELS - 2; i >= 0; i--) {
                target(R.fb_bloom[i], R.bloom_w[i], R.bloom_h[i]);
                sampler(program, "u_input", 0, GL_TEXTURE_2D, R.bloom[i + 1]);
                gl.Uniform2f(LOC("u_texel"), 1.0f / (float)R.bloom_w[i + 1], 1.0f / (float)R.bloom_h[i + 1]);
                fullscreen();
            }
            gl.Disable(GL_BLEND);
        }
    }

    /* 6. Post: exposure, bloom, tone curve, grading, sRGB, dither. */
    int w = R.w, h = R.h;
    if (R.s.supersample > 1) target(R.fb_final_ss, R.sw, R.sh);
    else target(R.fb_final, w, h);
    program = use(P_POST);
    sampler(program, "u_input", 0, GL_TEXTURE_2D, scene);
    gl.Uniform1i(LOC("u_palette_size"), f->palette_size);
    if (f->palette_size) gl.Uniform3fv(LOC("u_palette"), f->palette_size, &f->palette[0][0]);
    sampler(program, "u_bloom", 1, GL_TEXTURE_2D, R.s.hdr && R.s.bloom ? R.bloom[0] : R.white);
    sampler(program, "u_exposure", 2, GL_TEXTURE_2D, R.s.hdr ? R.exposure[R.exposure_index] : R.white);
    gl.Uniform1f(LOC("u_contrast"), f->contrast);
    gl.Uniform1f(LOC("u_saturation"), f->saturation);
    gl.Uniform3fv(LOC("u_tint"), 1, f->tint);
    fullscreen();

    /* 7. Supersampling: a linear blit to half size is exactly a 2x2 box filter. */
    if (R.s.supersample > 1) {
        gl.BindFramebuffer(GL_READ_FRAMEBUFFER, R.fb_final_ss);
        gl.BindFramebuffer(GL_DRAW_FRAMEBUFFER, R.fb_final);
        gl.BlitFramebuffer(0, 0, R.sw, R.sh, 0, 0, w, h, GL_COLOR_BUFFER_BIT, GL_LINEAR);
    }

    /* 8. Overlay: meshes and sprite runs (text, rectangles), unlit, in draw order, on the finished image. */
    target(R.fb_final, w, h);
    if (f->nsprites) { /* two triangles per sprite: x, y, u, v, r, g, b, a per vertex */
        static float *vertices;
        static int capacity;
        if (f->nsprites > capacity) {
            capacity = f->nsprites * 2;
            float *grown = realloc(vertices, (size_t)capacity * 6 * 8 * sizeof(float));
            if (!grown) abort(); /* out of memory while drawing: nothing sensible to continue with */
            vertices = grown;
        }
        for (int i = 0; i < f->nsprites; i++) {
            const fk_sprite *q = &f->sprites[i];
            const float corners[6][4] = {{q->x, q->y, q->u0, q->v0},
                                         {q->x + q->w, q->y, q->u1, q->v0},
                                         {q->x + q->w, q->y + q->h, q->u1, q->v1},
                                         {q->x, q->y, q->u0, q->v0},
                                         {q->x + q->w, q->y + q->h, q->u1, q->v1},
                                         {q->x, q->y + q->h, q->u0, q->v1}};
            for (int c = 0; c < 6; c++) {
                memcpy(&vertices[(i * 6 + c) * 8], corners[c], 4 * sizeof(float));
                memcpy(&vertices[(i * 6 + c) * 8 + 4], q->color, 4 * sizeof(float));
            }
        }
        gl.BindBuffer(GL_ARRAY_BUFFER, R.sprite_vbo);
        gl.BufferData(GL_ARRAY_BUFFER, (GLsizeiptr)f->nsprites * 6 * 8 * (GLsizeiptr)sizeof(float), vertices, GL_STREAM_DRAW);
    }
    gl.BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    for (int i = 0; i < f->noverlays; i++) {
        const fk_overlay *o = &f->overlays[i];
        if (o->mesh) {
            program = use(P_OVERLAY);
            gl.UniformMatrix4fv(LOC("u_mvp"), 1, GL_FALSE, o->matrix);
            gl.BindVertexArray(o->mesh->vao);
            gl.DrawElements(GL_TRIANGLES, o->mesh->count, GL_UNSIGNED_INT, (const void *)0);
        } else {
            program = use(P_SPRITE);
            sampler(program, "u_font", 0, GL_TEXTURE_2D, R.font);
            gl.Uniform2f(LOC("u_size"), (float)w, (float)h);
            gl.Enable(GL_BLEND);
            gl.BindVertexArray(R.sprite_vao);
            gl.DrawArrays(GL_TRIANGLES, o->first * 6, o->count * 6);
            gl.Disable(GL_BLEND);
        }
    }

    /* 9. The window: black bars around the integer-scaled image. */
    int rect[4];
    fk_gfx_upscale_rect(window_w, window_h, w, h, rect);
    fk_gfx_set_window(window_w, window_h, rect);
    fk_gfx_clear_window(0, 0, 0);
    gl.BindFramebuffer(GL_READ_FRAMEBUFFER, R.fb_final);
    gl.BlitFramebuffer(0, 0, w, h, rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3], GL_COLOR_BUFFER_BIT, GL_NEAREST);
    /* Leave nothing of ours bound: Chrome stops showing a WebGL canvas once a texture of the bound read
       framebuffer is deleted, which is what reconfiguring does. */
    gl.BindFramebuffer(GL_FRAMEBUFFER, 0);
    gl.BindVertexArray(0);
}

void fk_gfx_clear_window(float r, float g, float b) {
    int w, h;
    fk_platform_size(&w, &h);
    gl.BindFramebuffer(GL_FRAMEBUFFER, 0);
    gl.Viewport(0, 0, w, h);
    gl.ClearColor(r, g, b, 1.0f);
    gl.Clear(GL_COLOR_BUFFER_BIT);
}

void fk_gfx_read_pixels(uint8_t *rgba) {
    int w = R.w, h = R.h;
    gl.BindFramebuffer(GL_READ_FRAMEBUFFER, R.fb_final);
    gl.PixelStorei(GL_PACK_ALIGNMENT, 1);
    gl.ReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, rgba);
    size_t row = (size_t)w * 4;
    for (int y = 0; y < h / 2; y++) { /* GL's first row is the bottom one */
        uint8_t *a = rgba + (size_t)y * row, *b = rgba + (size_t)(h - 1 - y) * row;
        for (size_t i = 0; i < row; i++) {
            uint8_t t = a[i];
            a[i] = b[i];
            b[i] = t;
        }
    }
}
