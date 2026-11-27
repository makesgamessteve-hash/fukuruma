#include "script/script.h"

#include <stdio.h>
#include <string.h>

#include "assets/vfs.h"
#include "core/rng.h"
#include "gfx/frame.h"
#include "lauxlib.h"
#include "lualib.h"
#include "platform/platform.h"

#define FK_MAX_VERTICES (1 << 20)

static char last_error[4096];

const char *fk_script_error(void) { return last_error; }

void fk_script_set_error(const char *message) {
    snprintf(last_error, sizeof last_error, "%s", message);
    fk_log("%s", last_error);
}

/* --- fk.rng and fk.hash --------------------------------------------------------- */

/* Hashes the arguments from index first on: strings and integers, each with a type tag. */
static uint64_t hash_keys(lua_State *L, int first, uint64_t h) {
    for (int i = first, n = lua_gettop(L); i <= n; i++) {
        if (lua_type(L, i) == LUA_TSTRING) {
            size_t len;
            const char *str = lua_tolstring(L, i, &len);
            h = fk_hash_bytes(fk_hash_u64(fk_hash_bytes(h, "s", 1), len), str, len);
        } else if (lua_isinteger(L, i)) {
            h = fk_hash_u64(fk_hash_bytes(h, "i", 1), (uint64_t)lua_tointeger(L, i));
        } else {
            luaL_argerror(L, i, "keys must be strings or integers");
        }
    }
    return h;
}

static int l_hash(lua_State *L) {
    luaL_checkany(L, 1);
    lua_pushinteger(L, (lua_Integer)fk_mix64(hash_keys(L, 1, FK_HASH_INIT)));
    return 1;
}

static int l_rng(lua_State *L) {
    luaL_checkany(L, 1);
    lua_getfield(L, LUA_REGISTRYINDEX, "fk.seed");
    uint64_t world = (uint64_t)lua_tointeger(L, -1);
    lua_pop(L, 1);
    uint64_t seed = fk_mix64(hash_keys(L, 1, fk_hash_u64(FK_HASH_INIT, world)));
    fk_rng *r = lua_newuserdatauv(L, sizeof *r, 0);
    fk_rng_seed(r, seed);
    luaL_setmetatable(L, "fk.rng");
    return 1;
}

static int l_rng_int(lua_State *L) {
    lua_pushinteger(L, (lua_Integer)fk_rng_next(luaL_checkudata(L, 1, "fk.rng")));
    return 1;
}

static int l_rng_float(lua_State *L) {
    lua_pushnumber(L, fk_rng_float(luaL_checkudata(L, 1, "fk.rng")));
    return 1;
}

static int l_rng_range(lua_State *L) {
    fk_rng *r = luaL_checkudata(L, 1, "fk.rng");
    lua_Integer lo = luaL_checkinteger(L, 2), hi = luaL_checkinteger(L, 3);
    luaL_argcheck(L, lo <= hi, 3, "must not be smaller than the lower bound");
    uint64_t span = (uint64_t)hi - (uint64_t)lo + 1; /* 0 means the whole 64-bit range */
    lua_pushinteger(L, (lua_Integer)((uint64_t)lo + (span ? fk_rng_below(r, span) : fk_rng_next(r))));
    return 1;
}

static int l_rng_chance(lua_State *L) {
    fk_rng *r = luaL_checkudata(L, 1, "fk.rng");
    lua_pushboolean(L, fk_rng_float(r) < luaL_checknumber(L, 2));
    return 1;
}

/* --- fk.input ----------------------------------------------------------------- */

/* Looks up a control name with lookup(); raises a script error naming it when unknown. */
int fk_script_control(lua_State *L, int arg, int (*lookup)(const char *), const char *what) {
    const char *name = luaL_checkstring(L, arg);
    int code = lookup(name);
    if (code < 0) luaL_error(L, "unknown %s '%s'", what, name);
    return code;
}

static int l_key(lua_State *L) {
    lua_pushboolean(L, fk_input_key(fk_script_control(L, 1, fk_input_key_code, "key")));
    return 1;
}

static int l_axis(lua_State *L) {
    lua_pushnumber(L, fk_input_axis(fk_script_control(L, 1, fk_input_axis_code, "gamepad axis")));
    return 1;
}

static int l_button(lua_State *L) {
    lua_pushboolean(L, fk_input_button(fk_script_control(L, 1, fk_input_button_code, "gamepad button")));
    return 1;
}

static int l_mouse(lua_State *L) {
    float x, y, dx, dy;
    fk_input_mouse(&x, &y, &dx, &dy);
    fk_gfx_map_point(&x, &y); /* relative to the game image, not the window with its bars */
    fk_gfx_map_delta(&dx, &dy);
    lua_pushnumber(L, x);
    lua_pushnumber(L, y);
    lua_pushnumber(L, dx);
    lua_pushnumber(L, dy);
    return 4;
}

/* fk.input.capture(on): mouse look (the cursor is hidden and the mouse moves the view). */
static int l_capture(lua_State *L) {
    fk_platform_capture_mouse(lua_toboolean(L, 1));
    return 0;
}

static int l_mouse_button(lua_State *L) {
    lua_pushboolean(L, fk_input_mouse_button((int)luaL_checkinteger(L, 1)));
    return 1;
}

/* fk.input.xr() -> nil, or {ipd, rotation = {x, y, z, w}} while a VR headset's session runs (webxr spec) */
static int l_xr(lua_State *L) {
    float ipd, q[4];
    if (!fk_input_xr(&ipd, q)) return 0;
    lua_createtable(L, 0, 2);
    lua_pushnumber(L, ipd);
    lua_setfield(L, -2, "ipd");
    lua_createtable(L, 0, 4);
    static const char *const names[4] = {"x", "y", "z", "w"};
    for (int i = 0; i < 4; i++) {
        lua_pushnumber(L, q[i]);
        lua_setfield(L, -2, names[i]);
    }
    lua_setfield(L, -2, "rotation");
    return 1;
}

static int l_touches(lua_State *L) {
    fk_touch touches[FK_MAX_TOUCHES];
    int n = fk_input_touches(touches);
    lua_createtable(L, n, 0);
    for (int i = 0; i < n; i++) {
        fk_gfx_map_point(&touches[i].x, &touches[i].y);
        lua_createtable(L, 0, 3);
        lua_pushinteger(L, touches[i].id);
        lua_setfield(L, -2, "id");
        lua_pushnumber(L, touches[i].x);
        lua_setfield(L, -2, "x");
        lua_pushnumber(L, touches[i].y);
        lua_setfield(L, -2, "y");
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

/* fk.input.rumble(low, high, seconds): gamepad motors (0..1) or, on a phone, a vibration. */
static int l_rumble(lua_State *L) {
    lua_Number low = luaL_checknumber(L, 1), high = luaL_checknumber(L, 2), seconds = luaL_checknumber(L, 3);
    luaL_argcheck(L, low >= 0 && low <= 1, 1, "must be from 0 to 1");
    luaL_argcheck(L, high >= 0 && high <= 1, 2, "must be from 0 to 1");
    luaL_argcheck(L, seconds >= 0 && seconds <= 5, 3, "must be from 0 to 5 seconds");
    fk_input_rumble((float)low, (float)high, (int)(seconds * 1000));
    return 0;
}

static int l_device(lua_State *L) {
    lua_pushstring(L, fk_input_device());
    return 1;
}

/* --- sandbox ----------------------------------------------------------------- */

/* fk.seed() returns the world seed; fk.seed(n) sets it (loading a save), so new streams follow it. */
static int l_seed(lua_State *L) {
    if (!lua_isnoneornil(L, 1)) fk_script_set_seed(L, (uint64_t)luaL_checkinteger(L, 1));
    lua_getfield(L, LUA_REGISTRYINDEX, "fk.seed");
    return 1;
}

static int l_print(lua_State *L) {
    int n = lua_gettop(L); /* before luaL_buffinit, which may push a placeholder */
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    for (int i = 1; i <= n; i++) {
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
    static const luaL_Reg rng_methods[] = {
        {"int", l_rng_int}, {"float", l_rng_float}, {"range", l_rng_range}, {"chance", l_rng_chance}, {NULL, NULL}};
    luaL_newmetatable(L, "fk.rng");
    luaL_newlib(L, rng_methods);
    lua_setfield(L, -2, "__index");
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
    lua_pushcfunction(L, l_rng);
    lua_setfield(L, -2, "rng");
    lua_pushcfunction(L, l_hash);
    lua_setfield(L, -2, "hash");
    fk_lua_gfx_open(L, render);
    lua_setfield(L, -2, "gfx");
    fk_lua_storage_open(L);
    lua_setfield(L, -2, "storage");
    fk_lua_anim_open(L);
    lua_setfield(L, -2, "anim");
    fk_lua_audio_open(L);
    lua_setfield(L, -2, "audio");
    fk_lua_orbit_open(L);
    fk_lua_physics_open(L);
    lua_setfield(L, -2, "physics");
    fk_lua_galaxy_open(L);
    lua_setfield(L, -2, "galaxy");
    fk_lua_noise_open(L);
    lua_setfield(L, -2, "noise");
    fk_lua_planet_open(L);
    lua_setfield(L, -2, "planet");
    static const luaL_Reg input[] = {{"key", l_key},       {"axis", l_axis},       {"button", l_button},
                                     {"mouse", l_mouse},   {"mouse_button", l_mouse_button},
                                     {"touches", l_touches}, {"xr", l_xr}, {"device", l_device}, {"rumble", l_rumble}, {"capture", l_capture}, {NULL, NULL}};
    luaL_newlib(L, input);
    lua_setfield(L, -2, "input");
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
