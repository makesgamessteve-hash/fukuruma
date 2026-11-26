/* fk.storage: small text values by name, in the user's application-data folder (IndexedDB on the web),
   or only in memory for test runs. */
#include <stdio.h>
#include <string.h>

#include "lauxlib.h"
#include "platform/platform.h"
#include "script/script.h"

#define FK_STORAGE_MAX (64 * 1024)

static bool memory = true; /* safe default: nothing touches the disk unless the app asks for it */

void fk_storage_memory(bool in_memory) { memory = in_memory; }

static const char *checked_name(lua_State *L) {
    const char *name = luaL_checkstring(L, 1);
    size_t n = strlen(name);
    if (n == 0 || n > 64 || strspn(name, "abcdefghijklmnopqrstuvwxyz0123456789_") != n)
        luaL_error(L, "storage: '%s' is not a valid name (use 1 to 64 lowercase letters, digits and _)", name);
    return name;
}

static void push_memory(lua_State *L) {
    if (lua_getfield(L, LUA_REGISTRYINDEX, "fk.storage") == LUA_TTABLE) return;
    lua_pop(L, 1);
    lua_newtable(L);
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "fk.storage");
}

static int l_save(lua_State *L) {
    const char *name = checked_name(L);
    size_t len;
    const char *text = luaL_checklstring(L, 2, &len);
    if (len > FK_STORAGE_MAX) return luaL_error(L, "storage: the value for '%s' is larger than 64 KiB", name);
    if (memory) {
        push_memory(L);
        lua_pushvalue(L, 2);
        lua_setfield(L, -2, name);
        return 0;
    }
    char path[1024];
    const char *dir = fk_platform_pref_path();
    snprintf(path, sizeof path, "%s%s.txt", dir ? dir : "", name);
    if (!dir || !fk_platform_write_file(path, text, len)) return luaL_error(L, "storage: cannot write %s", path);
    fk_platform_storage_sync();
    return 0;
}

static int l_load(lua_State *L) {
    const char *name = checked_name(L);
    if (memory) {
        push_memory(L);
        lua_getfield(L, -1, name);
        return 1;
    }
    char path[1024];
    const char *dir = fk_platform_pref_path();
    snprintf(path, sizeof path, "%s%s.txt", dir ? dir : "", name);
    size_t size;
    char *text = dir ? fk_platform_read_file(path, &size) : NULL;
    if (text) lua_pushlstring(L, text, size);
    else lua_pushnil(L);
    fk_platform_free(text);
    return 1;
}

void fk_lua_storage_open(lua_State *L) {
    static const luaL_Reg storage[] = {{"save", l_save}, {"load", l_load}, {NULL, NULL}};
    luaL_newlib(L, storage);
}
