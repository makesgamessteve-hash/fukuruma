/* GL function loading, shader programs and meshes. */
#include <stddef.h>
#include <stdio.h>
#include <string.h>

#include "assets/vfs.h"
#include "gfx/gfx.h"
#include "gfx/gl.h"
#include "platform/platform.h"

#ifdef __EMSCRIPTEN__
#define FK_SHADER_HEADER                                                                                       \
    "#version 300 es\nprecision highp float;\nprecision highp int;\nprecision highp sampler2D;\n"              \
    "precision highp sampler2DArrayShadow;\n"
#else
#define FK_SHADER_HEADER "#version 330 core\n"
#endif

struct fk_gl_api fk_gl;

void fk_gl_load(void) {
#define X(ret, name, args) gl.name = (ret(FK_APIENTRY *) args)fk_platform_gl_proc("gl" #name);
    FK_GL_FUNCS(X)
#undef X
    gl.DepthRange = (void(FK_APIENTRY *)(fk_gl_depth, fk_gl_depth))fk_platform_gl_proc(FK_DEPTH_RANGE);
}

static GLuint compile(GLenum type, const char *const parts[5]) {
    GLuint shader = gl.CreateShader(type);
    gl.ShaderSource(shader, 5, parts, NULL);
    gl.CompileShader(shader);
    GLint ok = 0;
    gl.GetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[2048] = "";
        gl.GetShaderInfoLog(shader, (GLsizei)sizeof log, NULL, log);
        fk_log("shader compile error (%s): %s", parts[2], log);
        gl.DeleteShader(shader);
        return 0;
    }
    return shader;
}

GLuint fk_gl_program(const char *name, const char *defines) {
    char rel[128], path[1024];
    snprintf(rel, sizeof rel, "shaders/%s.glsl", name);
    char *common = fk_vfs_read("shaders/common.glsl", NULL), *source = fk_vfs_read(rel, NULL);
    GLuint program = 0, vs = 0, fs = 0;
    if (!common || !source) {
        fk_log("cannot find shader %s", fk_vfs_path(common ? rel : "shaders/common.glsl", path, sizeof path));
        goto done;
    }
    const char *vparts[5] = {FK_SHADER_HEADER, defines, "#define VERTEX\n", common, source};
    const char *fparts[5] = {FK_SHADER_HEADER, defines, "#define FRAGMENT\n", common, source};
    vs = compile(GL_VERTEX_SHADER, vparts);
    fs = compile(GL_FRAGMENT_SHADER, fparts);
    if (!vs || !fs) goto done;
    program = gl.CreateProgram();
    gl.AttachShader(program, vs);
    gl.AttachShader(program, fs);
    gl.BindAttribLocation(program, 0, "a_position");
    gl.BindAttribLocation(program, 1, "a_color");
    gl.BindAttribLocation(program, 2, "a_normal");
    gl.BindAttribLocation(program, 3, "a_uv");
    gl.BindAttribLocation(program, 4, "a_tangent");
    gl.BindAttribLocation(program, 5, "a_joints");
    gl.BindAttribLocation(program, 6, "a_weights");
    gl.LinkProgram(program);
    GLint ok = 0;
    gl.GetProgramiv(program, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[2048] = "";
        gl.GetProgramInfoLog(program, (GLsizei)sizeof log, NULL, log);
        fk_log("shader link error (%s): %s", name, log);
        gl.DeleteProgram(program);
        program = 0;
    }
done:
    if (vs) gl.DeleteShader(vs);
    if (fs) gl.DeleteShader(fs);
    fk_platform_free(common);
    fk_platform_free(source);
    return program;
}

void fk_gfx_mesh_create(fk_mesh *m, const fk_vertex *vertices, int vertex_count, const uint32_t *indices, int index_count) {
    static const struct {
        int size;
        size_t offset;
    } attributes[] = {{3, offsetof(fk_vertex, position)}, {3, offsetof(fk_vertex, color)}, {3, offsetof(fk_vertex, normal)},
                      {2, offsetof(fk_vertex, uv)},       {4, offsetof(fk_vertex, tangent)}, {4, offsetof(fk_vertex, joints)},
                      {4, offsetof(fk_vertex, weights)}};
    const GLsizei stride = (GLsizei)sizeof(fk_vertex);
    gl.GenVertexArrays(1, &m->vao);
    gl.GenBuffers(1, &m->vbo);
    gl.GenBuffers(1, &m->ibo);
    gl.BindVertexArray(m->vao);
    gl.BindBuffer(GL_ARRAY_BUFFER, m->vbo);
    gl.BufferData(GL_ARRAY_BUFFER, (GLsizeiptr)vertex_count * stride, vertices, GL_STATIC_DRAW);
    gl.BindBuffer(GL_ELEMENT_ARRAY_BUFFER, m->ibo);
    gl.BufferData(GL_ELEMENT_ARRAY_BUFFER, (GLsizeiptr)index_count * (GLsizeiptr)sizeof(uint32_t), indices, GL_STATIC_DRAW);
    for (GLuint a = 0; a < sizeof attributes / sizeof *attributes; a++) {
        gl.VertexAttribPointer(a, attributes[a].size, GL_FLOAT, GL_FALSE, stride, (const void *)attributes[a].offset);
        gl.EnableVertexAttribArray(a);
    }
    gl.BindVertexArray(0);
    m->count = index_count;
}

void fk_gfx_mesh_destroy(fk_mesh *m) {
    gl.DeleteBuffers(1, &m->vbo);
    gl.DeleteBuffers(1, &m->ibo);
    gl.DeleteVertexArrays(1, &m->vao);
    memset(m, 0, sizeof *m);
}

void fk_gfx_texture_upload(fk_texture *t, const uint8_t *rgba, int width, int height, bool srgb) {
    if (!t->id) gl.GenTextures(1, &t->id);
    gl.BindTexture(GL_TEXTURE_2D, t->id);
    gl.PixelStorei(GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(GL_TEXTURE_2D, 0, srgb ? GL_SRGB8_ALPHA8 : GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba);
    gl.GenerateMipmap(GL_TEXTURE_2D);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    t->width = width;
    t->height = height;
}

void fk_gfx_texture_destroy(fk_texture *t) {
    if (t->id) gl.DeleteTextures(1, &t->id);
    memset(t, 0, sizeof *t);
}
