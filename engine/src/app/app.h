/* The application: runs the Lua game, the Lua unit tests or a game-test scenario. SDL-free. */
#pragma once
#include <stdbool.h>

#include "lua.h"

typedef enum { FK_RUNNING, FK_DONE, FK_FAILED } fk_status;

#define FK_TICK (1.0 / 60.0) /* seconds of game time per simulation tick */
#define FK_MAX_TICKS 8       /* per frame; a longer backlog is dropped */

/* Adds dt seconds of real time to the accumulator and returns how many ticks are due.
   alpha receives the fraction of a tick left over, for interpolated drawing. */
int fk_ticks_due(double *acc, double dt, double *alpha);

/* base: the executable's folder (ending with a separator). */
fk_status fk_app_init(int argc, char **argv, const char *base);
fk_status fk_app_iterate(void);
/* Releases everything and returns the exit code (0 ok, 1 failure, 2 scenario timeout). */
int fk_app_quit(void);

/* Runs every *_test.lua below dir (see the test-harness spec). coverage: records Lua line coverage with luacov. */
bool fk_run_tests(lua_State *L, const char *dir, bool coverage);
