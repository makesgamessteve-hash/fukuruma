#include "assets/vfs.h"

#include <stdio.h>

#include "platform/platform.h"

static const char *base_path = "";

void fk_vfs_init(const char *base) { base_path = base ? base : ""; }

const char *fk_vfs_path(const char *rel, char *buf, size_t size) {
    snprintf(buf, size, "%sdata/%s", base_path, rel);
    return buf;
}

void *fk_vfs_read(const char *rel, size_t *size) {
    char path[1024];
    return fk_platform_read_file(fk_vfs_path(rel, path, sizeof path), size);
}
