/* fk.noise: noise graphs for scripts (gen/noise.h). A graph is a table of named nodes and an output:

     fk.noise.graph({ nodes = {
         base = { "fbm", frequency = 1.5, octaves = 6, seed = 3 },
         peaks = { "ridged", frequency = 4, octaves = 5, seed = 4 },
         height = { "add", "base", { "mul", "peaks", 0.4 } },
       }, output = "height" }, seed)

   A node is { op, inputs..., parameters... }; an input is a node's name, an inline node or a number. */
#include <string.h>

#include "core/rng.h"
#include "gen/noise.h"
#include "lauxlib.h"
#include "script/script.h"

static const char *const OPS[FK_N_COUNT + 1] = {"const", "perlin", "fbm", "ridged", "billow", "cells", "craters",
                                                "warp", "add", "sub", "mul", "min", "max", "blend", "scale", "clamp",
                                                "abs", "terrace", "smooth", "power", "latitude", NULL};
static const int INPUTS[FK_N_COUNT] = {0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 3, 1, 1, 1, 1, 1, 1, 0};

typedef struct {
    fk_noise *g;
    uint64_t seed;
    int nodes, output; /* stack indices: the nodes table and a table name -> compiled index (or -1 while compiling) */
} compiler;

static int compile(lua_State *L, compiler *c, int value);

static double opt(lua_State *L, int t, const char *name, double def) {
    lua_getfield(L, t, name);
    double v = lua_isnil(L, -1) ? def : (lua_isboolean(L, -1) ? lua_toboolean(L, -1) : luaL_checknumber(L, -1));
    lua_pop(L, 1);
    return v;
}

static int add(lua_State *L, compiler *c, fk_noise_node n) {
    if (c->g->count >= FK_NOISE_MAX_NODES) return luaL_error(L, "noise: more than %d nodes", FK_NOISE_MAX_NODES);
    c->g->nodes[c->g->count] = n;
    return c->g->count++;
}

/* Compiles the node table at t; returns its index. */
static int compile_node(lua_State *L, compiler *c, int t) {
    lua_rawgeti(L, t, 1);
    const char *name = lua_tostring(L, -1);
    int op = -1;
    for (int i = 0; name && OPS[i]; i++)
        if (!strcmp(OPS[i], name)) op = i;
    lua_pop(L, 1);
    if (op < 0) return luaL_error(L, "noise: unknown node '%s'", name ? name : "?");
    fk_noise_node n = {op, {-1, -1, -1}, {0, 0, 0}, 0, 0};
    for (int k = 0; k < INPUTS[op]; k++) {
        lua_rawgeti(L, t, k + 2);
        if (lua_isnil(L, -1)) return luaL_error(L, "noise: '%s' needs %d inputs", OPS[op], INPUTS[op]);
        n.in[k] = compile(L, c, lua_gettop(L));
        lua_pop(L, 1);
    }
    n.seed = fk_mix64(c->seed ^ (uint64_t)opt(L, t, "seed", 0) * 0x9e3779b97f4a7c15ull);
    switch (op) {
    case FK_N_CONST: n.p[0] = opt(L, t, "value", 0); break;
    case FK_N_PERLIN: n.p[0] = opt(L, t, "frequency", 1); break;
    case FK_N_FBM:
    case FK_N_RIDGED:
    case FK_N_BILLOW:
        n.p[0] = opt(L, t, "frequency", 1), n.p[1] = opt(L, t, "lacunarity", 2), n.p[2] = opt(L, t, "gain", 0.5);
        n.octaves = (int)opt(L, t, "octaves", 4);
        break;
    case FK_N_CELLS: n.p[0] = opt(L, t, "frequency", 1), n.p[1] = opt(L, t, "edges", 0); break;
    case FK_N_CRATERS: n.p[0] = opt(L, t, "frequency", 1), n.p[1] = opt(L, t, "density", 0.5); break;
    case FK_N_WARP: n.p[0] = opt(L, t, "strength", 0.3); break;
    case FK_N_SCALE: n.p[0] = opt(L, t, "scale", 1), n.p[1] = opt(L, t, "bias", 0); break;
    case FK_N_CLAMP: n.p[0] = opt(L, t, "lo", -1), n.p[1] = opt(L, t, "hi", 1); break;
    case FK_N_TERRACE: n.p[0] = opt(L, t, "steps", 4), n.p[1] = opt(L, t, "softness", 0.5); break;
    case FK_N_SMOOTH: n.p[0] = opt(L, t, "edge0", 0), n.p[1] = opt(L, t, "edge1", 1); break;
    case FK_N_POWER: n.p[0] = opt(L, t, "exponent", 1); break;
    default: break;
    }
    return add(L, c, n);
}

/* An input at value: a number (a constant), a node's name, or an inline node table. */
static int compile(lua_State *L, compiler *c, int value) {
    luaL_checkstack(L, 8, "noise: the graph is nested too deeply"); /* each level pushes a few values */
    if (lua_type(L, value) == LUA_TNUMBER) {
        fk_noise_node n = {FK_N_CONST, {-1, -1, -1}, {lua_tonumber(L, value), 0, 0}, 0, 0};
        return add(L, c, n);
    }
    if (lua_type(L, value) == LUA_TTABLE) return compile_node(L, c, value);
    const char *name = luaL_checkstring(L, value);
    lua_getfield(L, c->output, name);
    if (!lua_isnil(L, -1)) {
        int i = (int)lua_tointeger(L, -1);
        if (i < 0) return luaL_error(L, "noise: node '%s' depends on itself", name);
        lua_pop(L, 1);
        return i;
    }
    lua_pop(L, 1);
    if (lua_getfield(L, c->nodes, name) != LUA_TTABLE) return luaL_error(L, "noise: there is no node '%s'", name);
    lua_pushinteger(L, -1); /* compiling: a reference back to it is a cycle */
    lua_setfield(L, c->output, name);
    int i = compile_node(L, c, lua_gettop(L));
    lua_pop(L, 1);
    lua_pushinteger(L, i);
    lua_setfield(L, c->output, name);
    return i;
}

static int l_graph(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    uint64_t seed = (uint64_t)luaL_optinteger(L, 2, 0);
    lua_settop(L, 1);
    fk_noise *g = lua_newuserdatauv(L, sizeof *g, 0);
    memset(g, 0, sizeof *g);
    luaL_setmetatable(L, "fk.noise");
    compiler c = {g, seed, 0, 0};
    if (lua_getfield(L, 1, "nodes") != LUA_TTABLE) return luaL_error(L, "noise: 'nodes' must be a table");
    c.nodes = lua_gettop(L);
    lua_newtable(L);
    c.output = lua_gettop(L);
    lua_getfield(L, 1, "output");
    int out = compile(L, &c, lua_gettop(L));
    lua_pop(L, 3);
    if (out != g->count - 1) { /* the output must be last: copy it there */
        fk_noise_node n = {FK_N_SCALE, {out, -1, -1}, {1, 0, 0}, 0, 0};
        add(L, &c, n);
    }
    const char *why = fk_noise_check(g);
    if (why) return luaL_error(L, "noise: %s", why);
    return 1;
}

fk_noise *fk_lua_noise_arg(lua_State *L, int arg) { return luaL_checkudata(L, arg, "fk.noise"); }

static int l_eval(lua_State *L) {
    fk_noise *g = fk_lua_noise_arg(L, 1);
    lua_pushnumber(L, fk_noise_eval(g, luaL_checknumber(L, 2), luaL_checknumber(L, 3), luaL_checknumber(L, 4)));
    return 1;
}

static int l_count(lua_State *L) {
    lua_pushinteger(L, fk_lua_noise_arg(L, 1)->count);
    return 1;
}

void fk_lua_noise_open(lua_State *L) {
    static const luaL_Reg methods[] = {{"eval", l_eval}, {"count", l_count}, {NULL, NULL}};
    luaL_newmetatable(L, "fk.noise");
    luaL_newlib(L, methods);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    lua_createtable(L, 0, 1);
    lua_pushcfunction(L, l_graph);
    lua_setfield(L, -2, "graph");
}
