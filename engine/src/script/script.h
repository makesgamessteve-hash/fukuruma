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
/* Reads the control name at arg and looks it up (for example fk_input_key_code); raises a script error when unknown. */
int fk_script_control(lua_State *L, int arg, int (*lookup)(const char *), const char *what);

/* fk.gfx (script/lua_gfx.c): pushes the table. rendering: create GL meshes (otherwise only validate). */
void fk_lua_gfx_open(lua_State *L, bool rendering);
/* Starts a frame's recording: forgets last frame's draws and the meshes kept alive for them. */
void fk_script_frame_begin(lua_State *L);
/* fk.storage (script/lua_storage.c): pushes the table. */
void fk_lua_storage_open(lua_State *L);
/* true (the default): stored values live in memory only, as test runs need; false: the user's files. */
void fk_storage_memory(bool in_memory);
