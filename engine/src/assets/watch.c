#include "assets/watch.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "platform/platform.h"

typedef struct {
    char path[1024];
    int64_t mtime;
    uint64_t size;
    fk_watch_fn fn;
    void *user;
} watch;

static watch *list;
static int count, cap;

void fk_watch_add(const char *path, fk_watch_fn fn, void *user) {
    if (count == cap) {
        int next = cap ? cap * 2 : 16;
        watch *grown = realloc(list, (size_t)next * sizeof *list);
        if (!grown) return; /* hot reload is a convenience: without memory the file is simply not watched */
        list = grown, cap = next;
    }
    watch *w = &list[count++];
    snprintf(w->path, sizeof w->path, "%s", path);
    w->mtime = 0, w->size = 0;
    fk_platform_file_info(path, &w->mtime, &w->size);
    w->fn = fn, w->user = user;
}

void fk_watch_remove(void *user) {
    for (int i = 0; i < count; i++)
        if (list[i].user == user) list[i--] = list[--count];
}

void fk_watch_clear(void) {
    free(list);
    list = NULL;
    count = cap = 0;
}

int fk_watch_poll(void) {
    int changed = 0;
    for (int i = 0; i < count; i++) {
        int64_t mtime = 0;
        uint64_t size = 0;
        if (!fk_platform_file_info(list[i].path, &mtime, &size) || (mtime == list[i].mtime && size == list[i].size)) continue;
        list[i].mtime = mtime, list[i].size = size;
        changed++;
        list[i].fn(list[i].user); /* may add or remove watches: the loop re-reads count */
    }
    return changed;
}
