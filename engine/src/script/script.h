/* The Lua runtime: a sandboxed environment for game scripts and the fk.* API. */
#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "lua.h"

/* Creates a state. rendering: fk.gfx draws (otherwise it only validates its arguments).
   coverage: the host globals also get io, os, debug and package for luacov; scripts still see only the sandbox. */
lua_State *fk_script_open(bool rendering, uint64_t seed, bool coverage);
void fk_script_close(lua_State *L);
void fk_script_set_seed(lua_State *L, uint64_t seed);
/* Pushes the sandbox environment table. */
void fk_script_push_env(lua_State *L);
/* Loads text code with the sandbox as its environment and pushes the function. Logs and returns false on error. */
bool fk_script_load(lua_State *L, const char *code, size_t size, const char *chunkname);
bool fk_script_load_file(lua_State *L, const char *path);
/* Calls the function below nargs arguments, with a traceback on error. Logs and returns false on error. */
bool fk_script_call(lua_State *L, int nargs, int nresults);
/* The last error (message and traceback). */
const char *fk_script_error(void);
void fk_script_set_error(const char *message);
