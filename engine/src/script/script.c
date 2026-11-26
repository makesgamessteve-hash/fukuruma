#include "script/script.h"

#include <stdio.h>
#include <string.h>

#include "assets/vfs.h"
#include "gfx/gfx.h"
#include "lauxlib.h"
#include "lualib.h"
#include "platform/platform.h"

#define FK_MAX_VERTICES (1 << 20)

static bool rendering;
static char last_error[4096];

const char *fk_script_error(void) { return last_error; }

void fk_script_set_error(const char *message) {
    snprintf(last_error, sizeof last_error, "%s", message);
    fk_log("%s", last_error);
}

/* --- fk.gfx ---------------------------------------------------------------- */

static int l_clear(lua_State *L) {
    float r = (float)luaL_checknumber(L, 1), g = (float)luaL_checknumber(L, 2), b = (float)luaL_checknumber(L, 3);
    if (rendering) fk_gfx_clear(r, g, b);
    return 0;
}

static lua_Integer field_table(lua_State *L, const char *name) {
    if (lua_getfield(L, 1, name) != LUA_TTABLE) luaL_error(L, "mesh: '%s' must be a table", name);
    return luaL_len(L, -1);
}

static float number_at(lua_State *L, int table, lua_Integer i, const char *name) {
    lua_rawgeti(L, table, i);
    int ok;
    lua_Number v = lua_tonumberx(L, -1, &ok);
    if (!ok) luaL_error(L, "mesh: %s[%d] is not a number", name, (int)i);
    lua_pop(L, 1);
    return (float)v;
}

static int l_mesh(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_settop(L, 1);
    lua_Integer np = field_table(L, "positions"), nc = field_table(L, "colors"), ni = field_table(L, "indices");
    if (np == 0 || np % 3) return luaL_error(L, "mesh: positions must hold x, y, z for at least one vertex");
    if (nc != np) return luaL_error(L, "mesh: colors must hold r, g, b for every vertex");
    if (ni == 0 || ni % 3) return luaL_error(L, "mesh: indices must describe whole triangles");
    lua_Integer nv = np / 3;
    if (nv > FK_MAX_VERTICES || ni > 3 * FK_MAX_VERTICES) return luaL_error(L, "mesh: too large");
    /* Scratch buffers are userdata, so an error in the middle does not leak them. */
    float *v = lua_newuserdatauv(L, (size_t)nv * 6 * sizeof(float), 0);
    uint32_t *idx = lua_newuserdatauv(L, (size_t)ni * sizeof(uint32_t), 0);
    for (lua_Integer i = 0; i < nv; i++) {
        for (int k = 0; k < 3; k++) {
            v[i * 6 + k] = number_at(L, 2, i * 3 + k + 1, "positions");
            v[i * 6 + 3 + k] = number_at(L, 3, i * 3 + k + 1, "colors");
        }
    }
    for (lua_Integer i = 0; i < ni; i++) {
        lua_rawgeti(L, 4, i + 1);
        int ok;
        lua_Integer x = lua_tointegerx(L, -1, &ok);
        if (!ok || x < 1 || x > nv) return luaL_error(L, "mesh: indices[%d] must be a vertex number from 1 to %d", (int)i + 1, (int)nv);
        idx[i] = (uint32_t)(x - 1);
        lua_pop(L, 1);
    }
    fk_mesh *m = lua_newuserdatauv(L, sizeof *m, 0);
    memset(m, 0, sizeof *m);
    m->count = (int)ni;
    if (rendering) fk_gfx_mesh_create(m, v, (int)nv, idx, (int)ni);
    luaL_setmetatable(L, "fk.mesh");
    return 1;
}

static int l_mesh_gc(lua_State *L) {
    fk_mesh *m = luaL_checkudata(L, 1, "fk.mesh");
    if (m->vao) fk_gfx_mesh_destroy(m);
    return 0;
}

static int l_draw(lua_State *L) {
    fk_mesh *m = luaL_checkudata(L, 1, "fk.mesh");
    luaL_checktype(L, 2, LUA_TTABLE);
    if (luaL_len(L, 2) != 16) return luaL_error(L, "draw: the matrix must have 16 numbers");
    float mvp[16];
    for (int i = 0; i < 16; i++) {
        lua_rawgeti(L, 2, i + 1);
        int ok;
        mvp[i] = (float)lua_tonumberx(L, -1, &ok);
        if (!ok) return luaL_error(L, "draw: matrix[%d] is not a number", i + 1);
        lua_pop(L, 1);
    }
    if (rendering) fk_gfx_mesh_draw(m, mvp);
    return 0;
}

static int l_size(lua_State *L) {
    int w = FK_HEADLESS_W, h = FK_HEADLESS_H;
    if (rendering) fk_platform_size(&w, &h);
    lua_pushinteger(L, w);
    lua_pushinteger(L, h);
    return 2;
}

/* --- sandbox ----------------------------------------------------------------- */

static int l_seed(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "fk.seed");
    return 1;
}

static int l_print(lua_State *L) {
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    for (int i = 1, n = lua_gettop(L); i <= n; i++) {
        if (i > 1) luaL_addchar(&b, '\t');
        luaL_tolstring(L, i, NULL);
        luaL_addvalue(&b);
    }
    luaL_pushresult(&b);
    fk_log("%s", lua_tostring(L, -1));
    return 0;
}

static bool valid_module(const char *name) {
    if (!*name || *name == '.') return false;
    for (const char *p = name; *p; p++) {
        bool word = (*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') || (*p >= '0' && *p <= '9') || *p == '_';
        if (!word && !(*p == '.' && p[1] && p[1] != '.')) return false;
    }
    return true;
}

static int l_require(lua_State *L) {
    const char *name = luaL_checkstring(L, 1);
    lua_getfield(L, LUA_REGISTRYINDEX, "fk.loaded");
    if (lua_getfield(L, -1, name) != LUA_TNIL) return 1;
    if (!valid_module(name)) return luaL_error(L, "module name '%s' is not valid", name);
    char rel[256], path[1024];
    snprintf(rel, sizeof rel, "scripts/%s.lua", name);
    for (char *p = rel + 8; *p; p++)
        if (*p == '.' && strcmp(p, ".lua") != 0) *p = '/';
    size_t size;
    char *code = fk_vfs_read(rel, &size);
    if (!code) return luaL_error(L, "module '%s' not found: %s", name, fk_vfs_path(rel, path, sizeof path));
    char chunk[300];
    snprintf(chunk, sizeof chunk, "@data/%s", rel);
    int status = luaL_loadbufferx(L, code, size, chunk, "t");
    fk_platform_free(code);
    if (status != LUA_OK) return lua_error(L);
    fk_script_push_env(L);
    lua_setupvalue(L, -2, 1);
    lua_pushstring(L, name);
    lua_call(L, 1, 1);
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_pushboolean(L, 1);
    }
    lua_pushvalue(L, -1);
    lua_setfield(L, -4, name);
    return 1;
}

static void copy_globals(lua_State *L, const char *const *names) {
    for (; *names; names++) {
        lua_getglobal(L, *names);
        lua_setfield(L, -2, *names);
    }
}

lua_State *fk_script_open(bool render, uint64_t seed, bool coverage) {
    static const char *const safe[] = {"assert", "error", "ipairs", "next", "pairs", "pcall", "xpcall", "rawequal",
                                       "rawget", "rawlen", "rawset", "select", "setmetatable", "getmetatable",
                                       "tonumber", "tostring", "type", "_VERSION", "coroutine", "string", "table",
                                       "utf8", NULL};
    static const luaL_Reg libs[] = {{LUA_GNAME, luaopen_base},       {LUA_COLIBNAME, luaopen_coroutine},
                                    {LUA_TABLIBNAME, luaopen_table}, {LUA_STRLIBNAME, luaopen_string},
                                    {LUA_MATHLIBNAME, luaopen_math}, {LUA_UTF8LIBNAME, luaopen_utf8},
                                    {NULL, NULL}};
    static const luaL_Reg gfx[] = {{"clear", l_clear}, {"mesh", l_mesh}, {"draw", l_draw}, {"size", l_size}, {NULL, NULL}};
    rendering = render;
    lua_State *L = luaL_newstate();
    if (coverage) luaL_openlibs(L);
    else
        for (const luaL_Reg *lib = libs; lib->name; lib++) {
            luaL_requiref(L, lib->name, lib->func, 1);
            lua_pop(L, 1);
        }
    fk_script_set_seed(L, seed);
    lua_newtable(L);
    lua_setfield(L, LUA_REGISTRYINDEX, "fk.loaded");
    luaL_newmetatable(L, "fk.mesh");
    lua_pushcfunction(L, l_mesh_gc);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);

    lua_newtable(L); /* the sandbox environment */
    copy_globals(L, safe);
    lua_newtable(L); /* math without the global random generator: randomness comes from seeded streams */
    lua_getglobal(L, "math");
    lua_pushnil(L);
    while (lua_next(L, -2)) {
        const char *k = lua_tostring(L, -2);
        if (strcmp(k, "random") && strcmp(k, "randomseed")) lua_setfield(L, -4, k);
        else lua_pop(L, 1);
    }
    lua_pop(L, 1);
    lua_setfield(L, -2, "math");
    lua_pushcfunction(L, l_print);
    lua_setfield(L, -2, "print");
    lua_pushcfunction(L, l_require);
    lua_setfield(L, -2, "require");
    lua_newtable(L); /* fk */
    lua_pushcfunction(L, l_seed);
    lua_setfield(L, -2, "seed");
    luaL_newlib(L, gfx);
    lua_setfield(L, -2, "gfx");
    lua_setfield(L, -2, "fk");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "_G");
    lua_setfield(L, LUA_REGISTRYINDEX, "fk.env");
    return L;
}

void fk_script_close(lua_State *L) {
    if (L) lua_close(L);
}

void fk_script_set_seed(lua_State *L, uint64_t seed) {
    lua_pushinteger(L, (lua_Integer)seed);
    lua_setfield(L, LUA_REGISTRYINDEX, "fk.seed");
}

void fk_script_push_env(lua_State *L) { lua_getfield(L, LUA_REGISTRYINDEX, "fk.env"); }

bool fk_script_load(lua_State *L, const char *code, size_t size, const char *chunkname) {
    if (luaL_loadbufferx(L, code, size, chunkname, "t") != LUA_OK) {
        fk_script_set_error(lua_tostring(L, -1));
        lua_pop(L, 1);
        return false;
    }
    fk_script_push_env(L);
    lua_setupvalue(L, -2, 1);
    return true;
}

bool fk_script_load_file(lua_State *L, const char *path) {
    size_t size;
    char *code = fk_platform_read_file(path, &size);
    if (!code) {
        char msg[1100];
        snprintf(msg, sizeof msg, "cannot read %s", path);
        fk_script_set_error(msg);
        return false;
    }
    char chunk[1100];
    snprintf(chunk, sizeof chunk, "@%s", path);
    bool ok = fk_script_load(L, code, size, chunk);
    fk_platform_free(code);
    return ok;
}

static int traceback(lua_State *L) {
    luaL_traceback(L, L, luaL_tolstring(L, 1, NULL), 1);
    return 1;
}

bool fk_script_call(lua_State *L, int nargs, int nresults) {
    int base = lua_gettop(L) - nargs;
    lua_pushcfunction(L, traceback);
    lua_insert(L, base);
    int status = lua_pcall(L, nargs, nresults, base);
    lua_remove(L, base);
    if (status != LUA_OK) {
        fk_script_set_error(lua_tostring(L, -1));
        lua_pop(L, 1);
    }
    return status == LUA_OK;
}
