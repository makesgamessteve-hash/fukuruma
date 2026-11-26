/* The render pipeline: shadows, G-buffer, ambient occlusion, lighting, bloom, exposure, post,
   supersample filter, overlay and the integer upscale to the window. */
#include <math.h>
#include <stdio.h>
#include <string.h>

#include "core/mat4.h"
#include "gfx/frame.h"
#include "gfx/gfx.h"
#include "gfx/gl.h"
#include "gfx/shadow.h"
#include "platform/platform.h"

#define BLOOM_LEVELS 4
#define LUM_W 64
#define LUM_H 32
#define LUM_LOD 6.0f /* the 1x1 mip level of the 64x32 luminance target */

enum { P_GBUFFER, P_SHADOW, P_SSAO, P_BLUR, P_LIGHT, P_BRIGHT, P_DOWN, P_UP, P_LUM, P_EXPOSURE, P_POST, P_OVERLAY, P_COUNT };
static const char *const program_files[P_COUNT] = {"gbuffer", "shadow", "ssao",     "blur",     "lighting", "bloom",
                                                   "bloom",   "bloom",  "luminance", "exposure", "post",     "flat"};
static const char *const program_defines[P_COUNT] = {
    "",
    "",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n#define PREFILTER\n",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n#define UP\n",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n",
    "#define FULLSCREEN\n",
    ""};

static struct {
    bool hdr_supported;
    GLuint vao, white, programs[P_COUNT];
    GLuint g_base, g_normal, g_emission, g_depth, fb_gbuffer;
    GLuint shadow, fb_shadow;
    GLuint ao[2], fb_ao[2];
    GLuint light, fb_light;
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
                         R.exposure[1], R.final_ss, R.final};
    GLuint fbs[] = {R.fb_gbuffer, R.fb_shadow,   R.fb_ao[0],       R.fb_ao[1],       R.fb_light,    R.fb_bloom[0],
                    R.fb_bloom[1], R.fb_bloom[2], R.fb_bloom[3],    R.fb_lum,         R.fb_exposure[0],
                    R.fb_exposure[1], R.fb_final_ss, R.fb_final};
    gl.DeleteTextures((GLsizei)(sizeof textures / sizeof *textures), textures);
    gl.DeleteFramebuffers((GLsizei)(sizeof fbs / sizeof *fbs), fbs);
    bool hdr_supported = R.hdr_supported;
    GLuint vao = R.vao, white = R.white;
    memset(&R, 0, sizeof R);
    R.hdr_supported = hdr_supported, R.vao = vao, R.white = white;
}

bool fk_gfx_configure(void) {
    fk_gfx_settings *current = fk_gfx_settings_current();
    if (!R.hdr_supported) current->hdr = false; /* no float render targets: the LDR fallback */
    release();
    R.s = *current;
    int w = R.s.width, h = R.s.height;
    R.sw = w * R.s.supersample, R.sh = h * R.s.supersample;

    char defines[256], all[512];
    snprintf(defines, sizeof defines, "#define SHADOW_CASCADES %d\n#define SHADOW_SIZE %d\n#define AO_SAMPLES %d\n#define MAX_LIGHTS %d\n%s%s%s",
             R.s.shadow_cascades, R.s.shadow_size, R.s.ao_samples, R.s.max_lights, R.s.hdr ? "#define HDR\n" : "",
             R.s.hdr && R.s.bloom ? "#define BLOOM\n" : "", R.s.dither ? "#define DITHER\n" : "");
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
    return fk_gfx_configure();
}

void fk_gfx_shutdown(void) {
    release();
    gl.DeleteTextures(1, &R.white);
    gl.DeleteVertexArrays(1, &R.vao);
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

static void draw_meshes(GLuint program, bool materials) {
    fk_frame *f = fk_frame_get();
    for (int i = 0; i < f->ndraws; i++) {
        const fk_draw *d = &f->draws[i];
        gl.UniformMatrix4fv(LOC("u_model"), 1, GL_FALSE, d->model);
        if (materials) {
            gl.Uniform1f(LOC("u_roughness"), d->material.roughness);
            gl.Uniform1f(LOC("u_metalness"), d->material.metalness);
            gl.Uniform3fv(LOC("u_emission"), 1, d->material.emission);
        }
        gl.BindVertexArray(d->mesh->vao);
        gl.DrawElements(GL_TRIANGLES, d->mesh->count, GL_UNSIGNED_INT, (const void *)0);
    }
}

void fk_gfx_render(double dt, int window_w, int window_h) {
    fk_frame *f = fk_frame_get();
    float view_proj[16], inv_vp[16], inv_proj[16], inv_view[16];
    fk_mat4_mul(view_proj, f->projection, f->view);
    if (!fk_mat4_inverse(inv_vp, view_proj)) fk_mat4_identity(inv_vp);
    if (!fk_mat4_inverse(inv_proj, f->projection)) fk_mat4_identity(inv_proj);
    if (!fk_mat4_inverse(inv_view, f->view)) fk_mat4_identity(inv_view);
    const float *p = f->projection;
    bool perspective = p[11] == -1.0f;
    float z_near = perspective ? p[14] / (p[10] - 1.0f) : 0.1f, z_far = perspective ? p[14] / (p[10] + 1.0f) : 100.0f;
    GLuint program;

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
            fk_shadow_cascade(&cascades[c], inv_vp, z_near, z_far, d0, fk_shadow_split(c, nc, z_near, z_far), f->sun_dir, R.s.shadow_size);
            memcpy(&cascade_vp[c * 16], cascades[c].view_proj, sizeof cascades[c].view_proj);
            splits[c] = cascades[c].split;
            texels[c] = cascades[c].texel;
            gl.FramebufferTextureLayer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, R.shadow, 0, c);
            gl.Clear(GL_DEPTH_BUFFER_BIT);
            gl.UniformMatrix4fv(LOC("u_view_proj"), 1, GL_FALSE, cascades[c].view_proj);
            draw_meshes(program, false);
        }
        gl.Disable(GL_POLYGON_OFFSET_FILL);
    }

    /* 2. G-buffer. */
    target(R.fb_gbuffer, R.sw, R.sh);
    gl.ClearColor(0, 0, 0, 0);
    gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    program = use(P_GBUFFER);
    gl.UniformMatrix4fv(LOC("u_view_proj"), 1, GL_FALSE, view_proj);
    draw_meshes(program, true);
    gl.Disable(GL_DEPTH_TEST);
    gl.BindVertexArray(R.vao);

    /* 3. Ambient occlusion, then a 4x4 blur. */
    GLuint ao = R.white;
    if (R.s.ao_samples) {
        target(R.fb_ao[0], R.sw, R.sh);
        program = use(P_SSAO);
        sampler(program, "u_depth", 0, GL_TEXTURE_2D, R.g_depth);
        sampler(program, "u_normal", 1, GL_TEXTURE_2D, R.g_normal);
        gl.UniformMatrix4fv(LOC("u_inv_proj"), 1, GL_FALSE, inv_proj);
        gl.UniformMatrix4fv(LOC("u_proj"), 1, GL_FALSE, f->projection);
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
    gl.UniformMatrix4fv(LOC("u_inv_view_proj"), 1, GL_FALSE, inv_vp);
    gl.UniformMatrix4fv(LOC("u_view"), 1, GL_FALSE, f->view);
    if (nc) gl.UniformMatrix4fv(LOC("u_cascade"), nc, GL_FALSE, cascade_vp);
    gl.Uniform4fv(LOC("u_splits"), 1, splits);
    gl.Uniform4fv(LOC("u_texels"), 1, texels);
    gl.Uniform3fv(LOC("u_camera"), 1, &inv_view[12]);
    gl.Uniform3fv(LOC("u_sun_dir"), 1, f->sun_dir);
    gl.Uniform3fv(LOC("u_sun_color"), 1, f->sun_color);
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

    /* 5. HDR: average luminance, eye adaptation, bloom. */
    if (R.s.hdr) {
        target(R.fb_lum, LUM_W, LUM_H);
        program = use(P_LUM);
        sampler(program, "u_input", 0, GL_TEXTURE_2D, R.light);
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
                sampler(program, "u_input", 0, GL_TEXTURE_2D, i ? R.bloom[i - 1] : R.light);
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
    int w = R.s.width, h = R.s.height;
    if (R.s.supersample > 1) target(R.fb_final_ss, R.sw, R.sh);
    else target(R.fb_final, w, h);
    program = use(P_POST);
    sampler(program, "u_input", 0, GL_TEXTURE_2D, R.light);
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

    /* 8. Overlay: unlit, in draw order, on the finished image. */
    target(R.fb_final, w, h);
    program = use(P_OVERLAY);
    for (int i = 0; i < f->noverlays; i++) {
        gl.UniformMatrix4fv(LOC("u_mvp"), 1, GL_FALSE, f->overlays[i].matrix);
        gl.BindVertexArray(f->overlays[i].mesh->vao);
        gl.DrawElements(GL_TRIANGLES, f->overlays[i].mesh->count, GL_UNSIGNED_INT, (const void *)0);
    }

    /* 9. The window: black bars around the integer-scaled image. */
    int rect[4];
    fk_gfx_upscale_rect(window_w, window_h, w, h, rect);
    fk_gfx_set_window(window_w, window_h, rect);
    fk_gfx_clear_window(0, 0, 0);
    gl.BindFramebuffer(GL_READ_FRAMEBUFFER, R.fb_final);
    gl.BlitFramebuffer(0, 0, w, h, rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3], GL_COLOR_BUFFER_BIT, GL_NEAREST);
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
    int w = R.s.width, h = R.s.height;
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
