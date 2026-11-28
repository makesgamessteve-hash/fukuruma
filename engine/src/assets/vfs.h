/* Finds game files: in the mods' folders (mods/<name>/, the last in load order first), then in data/ beside the
   executable. */
#pragma once
#include <stdbool.h>
#include <stddef.h>

#define FK_VFS_MAX_MODS 16

/* base: the executable's folder, ending with a path separator. Clears the mods. */
void fk_vfs_init(const char *base);
/* The base folder given to fk_vfs_init. */
const char *fk_vfs_base(void);
/* Writes "<base>data/<rel>" into buf and returns buf. */
const char *fk_vfs_path(const char *rel, char *buf, size_t size);
/* Sets the mods (folder names under mods/, in load order); names that are not plain words are skipped. Returns how
   many were taken. */
int fk_vfs_set_mods(const char *const *names, int n);
/* Reads <rel> from the mods (last first), else data/<rel>; NULL when missing. NUL-terminated; free with
   fk_platform_free. */
void *fk_vfs_read(const char *rel, size_t *size);
