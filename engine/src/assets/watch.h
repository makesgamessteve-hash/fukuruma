/* Hot reload: remembers files and calls back when one changes (modification time or size). */
#pragma once
#include <stdbool.h>

typedef void (*fk_watch_fn)(void *user);

/* Watches the file at path (a full path); fn(user) runs from fk_watch_poll after it changes. */
void fk_watch_add(const char *path, fk_watch_fn fn, void *user);
void fk_watch_remove(void *user); /* forgets every file watched for user */
void fk_watch_clear(void);
/* Checks every watched file; calls back for the changed ones and returns how many changed. */
int fk_watch_poll(void);
