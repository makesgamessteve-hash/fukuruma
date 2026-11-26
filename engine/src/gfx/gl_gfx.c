/* The only file that calls OpenGL. Functions are loaded through the platform (no generated loader). */
#include <string.h>

#ifdef __EMSCRIPTEN__
#include <GLES3/gl3.h>
#define FK_APIENTRY
#define FK_SHADER_HEADER "#version 300 es\nprecision highp float;\n"
#else
#include <SDL3/SDL_opengl.h>
#if defined(_WIN32)
#define FK_APIENTRY __stdcall
#else
#define FK_APIENTRY
#endif
#define FK_SHADER_HEADER "#version 330 core\n"
#endif

#include "gfx/gfx.h"
#include "platform/platform.h"

#define FK_GL_FUNCS(X)                                                                                         \
    X(void, Viewport, (GLint, GLint, GLsizei, GLsizei))                                                        \
    X(void, ClearColor, (GLfloat, GLfloat, GLfloat, GLfloat))                                                  \
    X(void, Clear, (GLbitfield))                                                                               \
    X(void, Enable, (GLenum))                                                                                  \
    X(GLuint, CreateShader, (GLenum))                                                                          \
    X(void, ShaderSource, (GLuint, GLsizei, const GLchar *const *, const GLint *))                             \
    X(void, CompileShader, (GLuint))                                                                           \
    X(void, GetShaderiv, (GLuint, GLenum, GLint *))                                                            \
    X(void, GetShaderInfoLog, (GLuint, GLsizei, GLsizei *, GLchar *))                                          \
    X(void, DeleteShader, (GLuint))                                                                            \
    X(GLuint, CreateProgram, (void))                                                                           \
    X(void, AttachShader, (GLuint, GLuint))                                                                    \
    X(void, BindAttribLocation, (GLuint, GLuint, const GLchar *))                                              \
    X(void, LinkProgram, (GLuint))                                                                             \
    X(void, GetProgramiv, (GLuint, GLenum, GLint *))                                                           \
    X(void, GetProgramInfoLog, (GLuint, GLsizei, GLsizei *, GLchar *))                                         \
    X(void, DeleteProgram, (GLuint))                                                                           \
    X(void, UseProgram, (GLuint))                                                                              \
    X(GLint, GetUniformLocation, (GLuint, const GLchar *))                                                     \
    X(void, UniformMatrix4fv, (GLint, GLsizei, GLboolean, const GLfloat *))                                    \
    X(void, GenVertexArrays, (GLsizei, GLuint *))                                                              \
    X(void, BindVertexArray, (GLuint))                                                                         \
    X(void, DeleteVertexArrays, (GLsizei, const GLuint *))                                                     \
    X(void, GenBuffers, (GLsizei, GLuint *))                                                                   \
    X(void, BindBuffer, (GLenum, GLuint))                                                                      \
    X(void, BufferData, (GLenum, GLsizeiptr, const void *, GLenum))                                            \
    X(void, DeleteBuffers, (GLsizei, const GLuint *))                                                          \
    X(void, VertexAttribPointer, (GLuint, GLint, GLenum, GLboolean, GLsizei, const void *))                    \
    X(void, EnableVertexAttribArray, (GLuint))                                                                 \
    X(void, DrawElements, (GLenum, GLsizei, GLenum, const void *))                                             \
    X(void, PixelStorei, (GLenum, GLint))                                                                      \
    X(void, ReadPixels, (GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *))

static struct {
#define X(ret, name, args) ret(FK_APIENTRY *name) args;
    FK_GL_FUNCS(X)
#undef X
} gl;

static GLuint program;
static GLint mvp_location;

static GLuint compile(GLenum type, const char *define, const char *source) {
    const GLchar *parts[3] = {FK_SHADER_HEADER, define, source};
    GLuint shader = gl.CreateShader(type);
    gl.ShaderSource(shader, 3, parts, NULL);
    gl.CompileShader(shader);
    GLint ok = 0;
    gl.GetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[1024] = "";
        gl.GetShaderInfoLog(shader, (GLsizei)sizeof log, NULL, log);
        fk_log("shader compile error (%s): %s", define, log);
        gl.DeleteShader(shader);
        return 0;
    }
    return shader;
}

bool fk_gfx_init(const char *shader_source) {
#define X(ret, name, args) gl.name = (ret(FK_APIENTRY *) args)fk_platform_gl_proc("gl" #name);
    FK_GL_FUNCS(X)
#undef X
    GLuint vs = compile(GL_VERTEX_SHADER, "#define VERTEX\n", shader_source);
    GLuint fs = compile(GL_FRAGMENT_SHADER, "#define FRAGMENT\n", shader_source);
    if (!vs || !fs) return false;
    program = gl.CreateProgram();
    gl.AttachShader(program, vs);
    gl.AttachShader(program, fs);
    gl.BindAttribLocation(program, 0, "a_position");
    gl.BindAttribLocation(program, 1, "a_color");
    gl.LinkProgram(program);
    gl.DeleteShader(vs);
    gl.DeleteShader(fs);
    GLint ok = 0;
    gl.GetProgramiv(program, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[1024] = "";
        gl.GetProgramInfoLog(program, (GLsizei)sizeof log, NULL, log);
        fk_log("shader link error: %s", log);
        return false;
    }
    mvp_location = gl.GetUniformLocation(program, "u_mvp");
    gl.Enable(GL_DEPTH_TEST);
    return true;
}

void fk_gfx_shutdown(void) {
    if (program) gl.DeleteProgram(program);
    program = 0;
}

void fk_gfx_viewport(int w, int h) { gl.Viewport(0, 0, w, h); }

void fk_gfx_clear(float r, float g, float b) {
    gl.ClearColor(r, g, b, 1.0f);
    gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

void fk_gfx_mesh_create(fk_mesh *m, const float *vertices, int vertex_count, const uint32_t *indices, int index_count) {
    gl.GenVertexArrays(1, &m->vao);
    gl.GenBuffers(1, &m->vbo);
    gl.GenBuffers(1, &m->ibo);
    gl.BindVertexArray(m->vao);
    gl.BindBuffer(GL_ARRAY_BUFFER, m->vbo);
    const GLsizei stride = 6 * (GLsizei)sizeof(float);
    gl.BufferData(GL_ARRAY_BUFFER, (GLsizeiptr)vertex_count * stride, vertices, GL_STATIC_DRAW);
    gl.BindBuffer(GL_ELEMENT_ARRAY_BUFFER, m->ibo);
    gl.BufferData(GL_ELEMENT_ARRAY_BUFFER, (GLsizeiptr)index_count * (GLsizeiptr)sizeof(uint32_t), indices, GL_STATIC_DRAW);
    gl.VertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, stride, (const void *)0);
    gl.VertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, stride, (const void *)(3 * sizeof(float)));
    gl.EnableVertexAttribArray(0);
    gl.EnableVertexAttribArray(1);
    gl.BindVertexArray(0);
    m->count = index_count;
}

void fk_gfx_mesh_destroy(fk_mesh *m) {
    gl.DeleteBuffers(1, &m->vbo);
    gl.DeleteBuffers(1, &m->ibo);
    gl.DeleteVertexArrays(1, &m->vao);
    memset(m, 0, sizeof *m);
}

void fk_gfx_mesh_draw(const fk_mesh *m, const float mvp[16]) {
    gl.UseProgram(program);
    gl.UniformMatrix4fv(mvp_location, 1, GL_FALSE, mvp);
    gl.BindVertexArray(m->vao);
    gl.DrawElements(GL_TRIANGLES, m->count, GL_UNSIGNED_INT, (const void *)0);
    gl.BindVertexArray(0);
}

void fk_gfx_read_pixels(int w, int h, uint8_t *rgba) {
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
