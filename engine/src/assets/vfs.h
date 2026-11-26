/* Finds game files in the data folder beside the executable. */
#pragma once
#include <stddef.h>

/* base: the executable's folder, ending with a path separator. */
void fk_vfs_init(const char *base);
/* Writes "<base>data/<rel>" into buf and returns buf. */
const char *fk_vfs_path(const char *rel, char *buf, size_t size);
/* Reads data/<rel>; NULL when missing. NUL-terminated; free with fk_platform_free. */
void *fk_vfs_read(const char *rel, size_t *size);
