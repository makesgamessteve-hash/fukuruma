/* The only part of the engine that calls SDL: window, GL context, files, logging. */
#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* Size of the offscreen frame in headless runs (the Classic internal resolution). */
#define FK_HEADLESS_W 480
#define FK_HEADLESS_H 270

void fk_log(const char *fmt, ...);

/* Opens the window and the GL context (3.3 core, or ES 3.0 / WebGL 2 on the web).
   headless: SDL's offscreen driver, no visible window, fixed FK_HEADLESS_W x FK_HEADLESS_H. */
bool fk_platform_open(bool headless);
void fk_platform_close(void);
void fk_platform_size(int *w, int *h);
void fk_platform_swap(void);
typedef void (*fk_proc)(void);
fk_proc fk_platform_gl_proc(const char *name);
bool fk_platform_gl_extension(const char *name);
uint64_t fk_platform_ticks_ns(void);

/* Reads a whole file, NUL-terminated. Returns NULL when it cannot be read. Free with fk_platform_free. */
void *fk_platform_read_file(const char *path, size_t *size);
void fk_platform_free(void *p);
bool fk_platform_write_file(const char *path, const void *data, size_t size);
bool fk_platform_make_dir(const char *path);

/* Calls fn for every file below dir (recursively) whose name ends with suffix. */
typedef void (*fk_file_fn)(const char *path, void *user);
void fk_platform_find_files(const char *dir, const char *suffix, fk_file_fn fn, void *user);

void fk_platform_message(const char *title, const char *text);
bool fk_platform_web(void);   /* running in a browser */
bool fk_platform_phone(void); /* a browser on a device with a coarse pointer (phone, tablet) */
/* The folder for stored values (ends with a separator), or NULL when there is none. */
const char *fk_platform_pref_path(void);
/* Web: writes the IndexedDB-backed folder back to the browser. No-op elsewhere. */
void fk_platform_storage_sync(void);
/* Web only: publishes a scenario result as window.fukurumaResult. No-op elsewhere. */
void fk_platform_report(const char *status, const char *message);

/* --- Input (platform/input.c): one raw state, fed by SDL events and by scenario emulation --- */
#define FK_MAX_TOUCHES 10

typedef struct {
    int64_t id;
    float x, y; /* 0..1 across the window */
} fk_touch;

void fk_input_event(const void *sdl_event); /* every SDL_Event goes through here */
void fk_input_frame_end(void);               /* clears the per-frame mouse motion, applies held-back releases */
void fk_input_reset(void);                   /* releases everything */
int fk_input_key_code(const char *name);     /* SDL key name such as "W" or "Space"; -1 when unknown */
int fk_input_axis_code(const char *name);    /* SDL gamepad axis name such as "leftx"; -1 when unknown */
int fk_input_button_code(const char *name);  /* SDL gamepad button name such as "a"; -1 when unknown */
bool fk_input_key(int code);
bool fk_input_mouse_button(int button); /* 1 left, 2 middle, 3 right */
void fk_input_mouse(float *x, float *y, float *dx, float *dy);
float fk_input_axis(int code); /* sticks -1..1, triggers 0..1 */
bool fk_input_button(int code);
int fk_input_touches(fk_touch out[FK_MAX_TOUCHES]);
const char *fk_input_device(void); /* "keyboard", "mouse", "gamepad" or "touch": the latest input */

/* Scenario emulation: builds SDL events and passes them to fk_input_event. */
void fk_input_emulate_key(int code, bool down);
void fk_input_emulate_mouse_button(int button, bool down);
void fk_input_emulate_axis(int code, float value);
void fk_input_emulate_button(int code, bool down);
void fk_input_emulate_touch(int64_t id, bool down, float x, float y); /* down = false lifts the touch */
