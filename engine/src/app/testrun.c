/* Lua unit-test runner for --test. */
#include <string.h>

#include "app/app.h"
#include "lauxlib.h"
#include "platform/platform.h"
#include "script/script.h"

static void add_file(const char *path, void *user) {
    lua_State *L = user;
    lua_pushstring(L, path);
    lua_rawseti(L, -2, (lua_Integer)luaL_len(L, -2) + 1);
}

/* Calls a function of a host module, e.g. require("luacov.runner").init(). */
static bool host_call(lua_State *L, const char *module, const char *function) {
    lua_getglobal(L, "require");
    lua_pushstring(L, module);
    if (!fk_script_call(L, 1, 1)) return false;
    lua_getfield(L, -1, function);
    lua_remove(L, -2);
    return fk_script_call(L, 0, 0);
}

static void sort_top(lua_State *L) {
    lua_getglobal(L, "table");
    lua_getfield(L, -1, "sort");
    lua_remove(L, -2);
    lua_pushvalue(L, -2);
    lua_call(L, 1, 0);
}

bool fk_run_tests(lua_State *L, const char *dir, bool coverage) {
    if (coverage && !host_call(L, "luacov.runner", "init")) return false;
    int passed = 0, failed = 0, base = lua_gettop(L);
    int files = base + 1, tests = base + 3, names = base + 4;
    lua_newtable(L);
    fk_platform_find_files(dir, "_test.lua", add_file, L);
    sort_top(L);
    for (lua_Integer f = 1, nf = luaL_len(L, files); f <= nf; f++) {
        lua_rawgeti(L, files, f);
        const char *file = lua_tostring(L, -1);
        if (!fk_script_load_file(L, file) || !fk_script_call(L, 0, 1) || !lua_istable(L, -1)) {
            fk_log("FAIL %s: the file must return a table of test functions\n%s", file, fk_script_error());
            failed++;
            lua_settop(L, files);
            continue;
        }
        lua_newtable(L); /* names, sorted so the order is the same everywhere */
        lua_pushnil(L);
        while (lua_next(L, tests)) {
            lua_pop(L, 1);
            if (lua_type(L, -1) == LUA_TSTRING) {
                lua_pushvalue(L, -1);
                lua_rawseti(L, names, (lua_Integer)luaL_len(L, names) + 1);
            }
        }
        sort_top(L);
        for (lua_Integer t = 1, nt = luaL_len(L, names); t <= nt; t++) {
            lua_rawgeti(L, names, t);
            const char *name = lua_tostring(L, -1);
            lua_getfield(L, tests, name);
            bool is_fn = lua_isfunction(L, -1), ok = is_fn && fk_script_call(L, 0, 0);
            if (ok) fk_log("PASS %s: %s", file, name);
            else fk_log("FAIL %s: %s\n%s", file, name, is_fn ? fk_script_error() : "not a function");
            passed += ok;
            failed += !ok;
            lua_settop(L, names);
        }
        lua_settop(L, files);
    }
    lua_settop(L, base);
    fk_log("%d passed, %d failed", passed, failed);
    if (passed + failed == 0) fk_log("no *_test.lua files found in %s", dir);
    if (coverage && !(host_call(L, "luacov.runner", "shutdown") && host_call(L, "luacov.reporter", "report"))) return false;
    return failed == 0 && passed > 0;
}
