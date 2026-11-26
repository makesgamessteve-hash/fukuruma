#include "platform/platform.h"

#include <SDL3/SDL.h>
#include <stdarg.h>
#include <string.h>
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

static SDL_Window *window;
static SDL_GLContext context;

void fk_log(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    SDL_LogMessageV(SDL_LOG_CATEGORY_APPLICATION, SDL_LOG_PRIORITY_INFO, fmt, ap);
    va_end(ap);
}

bool fk_platform_open(bool headless) {
    if (headless) SDL_SetHint(SDL_HINT_VIDEO_DRIVER, "offscreen");
    if (!SDL_InitSubSystem(SDL_INIT_VIDEO)) {
        fk_log("cannot start video: %s", SDL_GetError());
        return false;
    }
#ifdef __EMSCRIPTEN__
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
#else
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
#endif
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_WindowFlags flags = SDL_WINDOW_OPENGL | (headless ? 0 : SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);
    window = SDL_CreateWindow("Fukuruma", headless ? FK_HEADLESS_W : 1280, headless ? FK_HEADLESS_H : 720, flags);
    if (window) context = SDL_GL_CreateContext(window);
    if (!context) {
        fk_log("cannot create an OpenGL context: %s", SDL_GetError());
        fk_platform_close();
        return false;
    }
    SDL_GL_SetSwapInterval(headless ? 0 : 1);
    return true;
}

void fk_platform_close(void) {
    if (context) SDL_GL_DestroyContext(context);
    if (window) SDL_DestroyWindow(window);
    context = NULL;
    window = NULL;
    SDL_QuitSubSystem(SDL_INIT_VIDEO);
}

void fk_platform_size(int *w, int *h) { SDL_GetWindowSizeInPixels(window, w, h); }
void fk_platform_swap(void) { SDL_GL_SwapWindow(window); }
void *fk_platform_gl_proc(const char *name) { return (void *)SDL_GL_GetProcAddress(name); }
uint64_t fk_platform_ticks_ns(void) { return SDL_GetTicksNS(); }

void *fk_platform_read_file(const char *path, size_t *size) { return SDL_LoadFile(path, size); }
void fk_platform_free(void *p) { SDL_free(p); }
bool fk_platform_write_file(const char *path, const void *data, size_t size) { return SDL_SaveFile(path, data, size); }
bool fk_platform_make_dir(const char *path) { return SDL_CreateDirectory(path); }

typedef struct {
    const char *suffix;
    fk_file_fn fn;
    void *user;
} find_ctx;

static SDL_EnumerationResult find_cb(void *user, const char *dir, const char *name) {
    find_ctx *ctx = user;
    char *path = NULL;
    SDL_asprintf(&path, "%s%s", dir, name);
    SDL_PathInfo info;
    if (path && SDL_GetPathInfo(path, &info)) {
        size_t n = strlen(name), s = strlen(ctx->suffix);
        if (info.type == SDL_PATHTYPE_DIRECTORY) SDL_EnumerateDirectory(path, find_cb, ctx);
        else if (n >= s && strcmp(name + n - s, ctx->suffix) == 0) ctx->fn(path, ctx->user);
    }
    SDL_free(path);
    return SDL_ENUM_CONTINUE;
}

void fk_platform_find_files(const char *dir, const char *suffix, fk_file_fn fn, void *user) {
    find_ctx ctx = {suffix, fn, user};
    SDL_EnumerateDirectory(dir, find_cb, &ctx);
}

void fk_platform_message(const char *title, const char *text) {
    SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, title, text, window);
}

#ifdef __EMSCRIPTEN__
EM_JS(void, fk_platform_report, (const char *status, const char *message), {
    window.fukurumaResult = {status : UTF8ToString(status), message : UTF8ToString(message)};
});
#else
void fk_platform_report(const char *status, const char *message) {
    (void)status;
    (void)message;
}
#endif
