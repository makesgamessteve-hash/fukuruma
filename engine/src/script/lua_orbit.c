/* fk.math (deterministic sin, cos, wrap) and fk.orbit (Kepler orbits on rails) for scripts. */
#include "core/dmath.h"
#include "core/orbit.h"
#include "lauxlib.h"
#include "script/script.h"

static int l_sin(lua_State *L) {
    lua_pushnumber(L, fk_dsin(luaL_checknumber(L, 1)));
    return 1;
}

static int l_cos(lua_State *L) {
    lua_pushnumber(L, fk_dcos(luaL_checknumber(L, 1)));
    return 1;
}

static int l_wrap(lua_State *L) {
    lua_pushnumber(L, fk_dwrap(luaL_checknumber(L, 1)));
    return 1;
}

static double field(lua_State *L, const char *name, double def, bool required) {
    int type = lua_getfield(L, 1, name);
    if (type == LUA_TNIL && !required) {
        lua_pop(L, 1);
        return def;
    }
    if (type != LUA_TNUMBER) luaL_error(L, "orbit: '%s' must be a number", name);
    double v = lua_tonumber(L, -1);
    lua_pop(L, 1);
    return v;
}

/* The elements table: a, e, mu (required), i, node, periapsis, anomaly, epoch (default 0). */
static fk_orbit elements(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    fk_orbit o = {field(L, "a", 0, true),      field(L, "e", 0, false),       field(L, "i", 0, false),
                  field(L, "node", 0, false),  field(L, "periapsis", 0, false), field(L, "anomaly", 0, false),
                  field(L, "epoch", 0, false), field(L, "mu", 0, true)};
    const char *why = fk_orbit_check(&o);
    if (why) luaL_error(L, "orbit: %s", why);
    return o;
}

static void push3(lua_State *L, const double v[3]) {
    lua_createtable(L, 3, 0);
    for (int i = 0; i < 3; i++) {
        lua_pushnumber(L, v[i]);
        lua_rawseti(L, -2, i + 1);
    }
}

/* fk.orbit.state(elements, t): position and velocity tables relative to the central body. */
static int l_state(lua_State *L) {
    fk_orbit o = elements(L);
    double p[3], v[3];
    fk_orbit_state(&o, luaL_checknumber(L, 2), p, v);
    push3(L, p);
    push3(L, v);
    return 2;
}

static int l_period(lua_State *L) {
    fk_orbit o = elements(L);
    lua_pushnumber(L, fk_orbit_period(&o));
    return 1;
}

void fk_lua_orbit_open(lua_State *L) {
    static const luaL_Reg math[] = {{"sin", l_sin}, {"cos", l_cos}, {"wrap", l_wrap}, {NULL, NULL}};
    static const luaL_Reg orbit[] = {{"state", l_state}, {"period", l_period}, {NULL, NULL}};
    luaL_newlib(L, math);
    lua_pushnumber(L, FK_PI);
    lua_setfield(L, -2, "pi");
    lua_setfield(L, -2, "math");
    luaL_newlib(L, orbit);
    lua_setfield(L, -2, "orbit");
}
