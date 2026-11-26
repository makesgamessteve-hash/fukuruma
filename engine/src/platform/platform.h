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
void *fk_platform_gl_proc(const char *name);
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
/* Web only: publishes a scenario result as window.fukurumaResult. No-op elsewhere. */
void fk_platform_report(const char *status, const char *message);
