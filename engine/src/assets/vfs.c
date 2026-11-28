#include "assets/vfs.h"

#include <stdio.h>
#include <string.h>

#include "platform/platform.h"

static const char *base_path = "";
static char mods[FK_VFS_MAX_MODS][64]; /* in load order: the last one wins */
static int nmods;

void fk_vfs_init(const char *base) {
    base_path = base ? base : "";
    nmods = 0;
}

const char *fk_vfs_path(const char *rel, char *buf, size_t size) {
    snprintf(buf, size, "%sdata/%s", base_path, rel);
    return buf;
}

const char *fk_vfs_base(void) { return base_path; }

/* A mod's folder name: letters, digits, '_' and '-' only (no paths). */
static bool valid_mod(const char *name) {
    size_t n = strlen(name);
    if (n == 0 || n >= sizeof mods[0]) return false;
    for (const char *p = name; *p; p++)
        if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') || (*p >= '0' && *p <= '9') || *p == '_' || *p == '-'))
            return false;
    return true;
}

int fk_vfs_set_mods(const char *const *names, int n) {
    nmods = 0;
    for (int i = 0; i < n && nmods < FK_VFS_MAX_MODS; i++)
        if (valid_mod(names[i])) snprintf(mods[nmods++], sizeof mods[0], "%s", names[i]);
    return nmods;
}

void *fk_vfs_read(const char *rel, size_t *size) {
    char path[1024];
    for (int i = nmods - 1; i >= 0; i--) { /* mods/<name>/<rel> over data/<rel> */
        snprintf(path, sizeof path, "%smods/%s/%s", base_path, mods[i], rel);
        void *data = fk_platform_read_file(path, size);
        if (data) return data;
    }
    return fk_platform_read_file(fk_vfs_path(rel, path, sizeof path), size);
}
