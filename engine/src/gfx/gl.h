/* Internal to gfx/gl_*.c, the only files that call OpenGL: GL headers and the loaded function table. */
#pragma once

#ifdef __EMSCRIPTEN__
#include <GLES3/gl3.h>
#define FK_APIENTRY
#define FK_DEPTH_RANGE "glDepthRangef" /* GL ES and WebGL take floats, desktop GL 3.3 takes doubles */
typedef GLfloat fk_gl_depth;
#else
#include <SDL3/SDL_opengl.h>
#define FK_DEPTH_RANGE "glDepthRange"
typedef GLdouble fk_gl_depth;
#if defined(_WIN32)
#define FK_APIENTRY __stdcall
#else
#define FK_APIENTRY
#endif
#endif

#define FK_GL_FUNCS(X)                                                                                         \
    X(const GLubyte *, GetString, (GLenum))                                                                    \
    X(void, Viewport, (GLint, GLint, GLsizei, GLsizei))                                                        \
    X(void, ClearColor, (GLfloat, GLfloat, GLfloat, GLfloat))                                                  \
    X(void, Clear, (GLbitfield))                                                                               \
    X(void, Enable, (GLenum))                                                                                  \
    X(void, Disable, (GLenum))                                                                                 \
    X(void, BlendFunc, (GLenum, GLenum))                                                                       \
    X(void, PolygonOffset, (GLfloat, GLfloat))                                                                 \
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
    X(void, Uniform1i, (GLint, GLint))                                                                         \
    X(void, Uniform1f, (GLint, GLfloat))                                                                       \
    X(void, Uniform2f, (GLint, GLfloat, GLfloat))                                                              \
    X(void, Uniform3fv, (GLint, GLsizei, const GLfloat *))                                                     \
    X(void, Uniform4fv, (GLint, GLsizei, const GLfloat *))                                                     \
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
    X(void, DrawArrays, (GLenum, GLint, GLsizei))                                                              \
    X(void, PixelStorei, (GLenum, GLint))                                                                      \
    X(void, ReadPixels, (GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *))                              \
    X(void, ReadBuffer, (GLenum))                                                                              \
    X(void, GenTextures, (GLsizei, GLuint *))                                                                  \
    X(void, DeleteTextures, (GLsizei, const GLuint *))                                                         \
    X(void, BindTexture, (GLenum, GLuint))                                                                     \
    X(void, ActiveTexture, (GLenum))                                                                           \
    X(void, TexImage2D, (GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *))         \
    X(void, TexImage3D, (GLenum, GLint, GLint, GLsizei, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *)) \
    X(void, TexParameteri, (GLenum, GLenum, GLint))                                                            \
    X(void, GenerateMipmap, (GLenum))                                                                          \
    X(void, GenFramebuffers, (GLsizei, GLuint *))                                                              \
    X(void, DeleteFramebuffers, (GLsizei, const GLuint *))                                                     \
    X(void, BindFramebuffer, (GLenum, GLuint))                                                                 \
    X(void, FramebufferTexture2D, (GLenum, GLenum, GLenum, GLuint, GLint))                                     \
    X(void, FramebufferTextureLayer, (GLenum, GLenum, GLuint, GLint, GLint))                                   \
    X(void, DrawBuffers, (GLsizei, const GLenum *))                                                            \
    X(GLenum, CheckFramebufferStatus, (GLenum))                                                                \
    X(void, BlitFramebuffer, (GLint, GLint, GLint, GLint, GLint, GLint, GLint, GLint, GLbitfield, GLenum))

struct fk_gl_api {
#define X(ret, name, args) ret(FK_APIENTRY *name) args;
    FK_GL_FUNCS(X)
#undef X
    void(FK_APIENTRY *DepthRange)(fk_gl_depth, fk_gl_depth);
};
extern struct fk_gl_api fk_gl;
#define gl fk_gl

void fk_gl_load(void);

/* Compiles shaders/common.glsl followed by shaders/<name>.glsl once as the vertex and once as the fragment
   stage, with the given #define lines. Returns 0 and logs on failure. */
GLuint fk_gl_program(const char *name, const char *defines);
