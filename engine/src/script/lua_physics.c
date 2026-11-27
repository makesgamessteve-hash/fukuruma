/* fk.physics: physics worlds for scripts (physics/physics.h). A world is simulation state: world:state() gives
   plain data that saves and the state hash include, and world:restore() continues from it exactly. */
#include <math.h>
#include <string.h>

#include "core/dmath.h"
#include "lauxlib.h"
#include "physics/physics.h"
#include "script/script.h"

typedef struct {
    fk_world *w;
} lua_world;

static fk_world *world_arg(lua_State *L) {
    lua_world *lw = luaL_checkudata(L, 1, "fk.world");
    return lw->w;
}

static float num(lua_State *L, int idx, const char *what) {
    int ok;
    lua_Number v = lua_tonumberx(L, idx, &ok);
    if (!ok || !isfinite(v)) luaL_error(L, "physics: '%s' must be a finite number", what);
    return (float)v;
}

/* t[name] as n numbers into out, or leaves out alone when absent. */
static bool vec(lua_State *L, int t, const char *name, float *out, int n) {
    int type = lua_getfield(L, t, name);
    if (type == LUA_TNIL) {
        lua_pop(L, 1);
        return false;
    }
    if (type != LUA_TTABLE || luaL_len(L, -1) != n) luaL_error(L, "physics: '%s' must be a table of %d numbers", name, n);
    for (int i = 0; i < n; i++) {
        lua_rawgeti(L, -1, i + 1);
        out[i] = num(L, -1, name);
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
    return true;
}

static float opt(lua_State *L, int t, const char *name, float def) {
    float v = def;
    if (lua_getfield(L, t, name) != LUA_TNIL) v = num(L, -1, name);
    lua_pop(L, 1);
    return v;
}

static float positive(lua_State *L, int t, const char *name, float def) {
    float v = opt(L, t, name, def);
    if (!(v > 0)) luaL_error(L, "physics: '%s' must be above 0", name);
    return v;
}

static void place(lua_State *L, int t, fk_body *b) {
    b->q[3] = 1;
    vec(L, t, "position", b->p, 3);
    vec(L, t, "rotation", b->q, 4);
    vec(L, t, "velocity", b->v, 3);
    vec(L, t, "spin", b->w, 3);
}

static int l_world(lua_State *L) {
    float g[3] = {0, -9.81f, 0};
    if (!lua_isnoneornil(L, 1)) {
        luaL_checktype(L, 1, LUA_TTABLE);
        vec(L, 1, "gravity", g, 3);
    }
    lua_world *lw = lua_newuserdatauv(L, sizeof *lw, 0);
    lw->w = fk_world_create(g);
    luaL_setmetatable(L, "fk.world");
    return 1;
}

static int l_gc(lua_State *L) {
    lua_world *lw = luaL_checkudata(L, 1, "fk.world");
    fk_world_destroy(lw->w);
    lw->w = NULL;
    return 0;
}

/* world:add{shape = "sphere" | "capsule" | "box", radius, height (capsule, end to end), size = {x, y, z} (box),
   mass (0: static), kinematic, position, rotation, velocity, spin, friction, restitution, gravity} -> id */
static int l_add(lua_State *L) {
    fk_world *w = world_arg(L);
    luaL_checktype(L, 2, LUA_TTABLE);
    static const char *const shapes[] = {"sphere", "capsule", "box", NULL};
    fk_body b;
    memset(&b, 0, sizeof b);
    lua_getfield(L, 2, "shape");
    b.shape.type = luaL_checkoption(L, -1, NULL, shapes);
    lua_pop(L, 1);
    if (b.shape.type == FK_SHAPE_BOX) {
        float size[3] = {0, 0, 0};
        if (!vec(L, 2, "size", size, 3) || !(size[0] > 0 && size[1] > 0 && size[2] > 0))
            return luaL_error(L, "physics: a box needs a 'size' above 0");
        for (int i = 0; i < 3; i++) b.shape.half[i] = size[i] / 2;
    } else {
        b.shape.radius = positive(L, 2, "radius", 0);
        if (b.shape.type == FK_SHAPE_CAPSULE) {
            float h = opt(L, 2, "height", 0);
            if (!(h >= 2 * b.shape.radius)) return luaL_error(L, "physics: a capsule's 'height' must be at least twice its radius");
            b.shape.half[1] = h / 2 - b.shape.radius;
        }
    }
    float mass = opt(L, 2, "mass", 0);
    if (!(mass >= 0)) return luaL_error(L, "physics: 'mass' must not be negative");
    lua_getfield(L, 2, "kinematic");
    bool kinematic = lua_toboolean(L, -1);
    lua_pop(L, 1);
    b.kind = kinematic ? FK_BODY_KINEMATIC : mass > 0 ? FK_BODY_DYNAMIC : FK_BODY_STATIC;
    place(L, 2, &b);
    b.friction = opt(L, 2, "friction", 0.5f);
    b.restitution = opt(L, 2, "restitution", 0);
    b.own_gravity = vec(L, 2, "gravity", b.gravity, 3);
    lua_pushinteger(L, fk_world_add(w, &b, mass));
    return 1;
}

/* world:character{radius, height, position, step = 0.4, slope = 50 (degrees), push = 0 (kg)} -> id */
static int l_character(lua_State *L) {
    fk_world *w = world_arg(L);
    luaL_checktype(L, 2, LUA_TTABLE);
    fk_body b;
    memset(&b, 0, sizeof b);
    b.kind = FK_BODY_CHARACTER, b.shape.type = FK_SHAPE_CAPSULE;
    b.shape.radius = positive(L, 2, "radius", 0.4f);
    float h = opt(L, 2, "height", 1.8f);
    if (!(h >= 2 * b.shape.radius)) return luaL_error(L, "physics: a capsule's 'height' must be at least twice its radius");
    b.shape.half[1] = h / 2 - b.shape.radius;
    place(L, 2, &b);
    b.step = opt(L, 2, "step", 0.4f);
    b.slope_cos = (float)fk_dcos(opt(L, 2, "slope", 50) * FK_PI / 180);
    b.push_mass = opt(L, 2, "push", 0);
    b.own_gravity = vec(L, 2, "gravity", b.gravity, 3);
    lua_pushinteger(L, fk_world_add(w, &b, 0));
    return 1;
}

static fk_body *body_arg(lua_State *L, fk_world *w) {
    lua_Integer id = luaL_checkinteger(L, 2);
    fk_body *b = id > 0 && id <= 0xffffffff ? fk_world_body(w, (uint32_t)id) : NULL;
    if (!b) luaL_error(L, "physics: there is no body %d", (int)id);
    return b;
}

static void push3(lua_State *L, const float *v, int n) {
    lua_createtable(L, n, 0);
    for (int i = 0; i < n; i++) {
        lua_pushnumber(L, v[i]);
        lua_rawseti(L, -2, i + 1);
    }
}

static int l_remove(lua_State *L) {
    fk_world *w = world_arg(L);
    lua_pushboolean(L, fk_world_remove(w, (uint32_t)luaL_checkinteger(L, 2)));
    return 1;
}

/* world:get(id) -> {position, rotation, velocity, spin, asleep, grounded} */
static int l_get(lua_State *L) {
    fk_body *b = body_arg(L, world_arg(L));
    lua_createtable(L, 0, 6);
    push3(L, b->p, 3);
    lua_setfield(L, -2, "position");
    push3(L, b->q, 4);
    lua_setfield(L, -2, "rotation");
    push3(L, b->v, 3);
    lua_setfield(L, -2, "velocity");
    push3(L, b->w, 3);
    lua_setfield(L, -2, "spin");
    lua_pushboolean(L, b->asleep);
    lua_setfield(L, -2, "asleep");
    lua_pushboolean(L, b->grounded);
    lua_setfield(L, -2, "grounded");
    return 1;
}

/* world:set(id, {position, rotation, velocity, spin}): moves a body and wakes it. */
static int l_set(lua_State *L) {
    fk_world *w = world_arg(L);
    fk_body *b = body_arg(L, w);
    luaL_checktype(L, 3, LUA_TTABLE);
    vec(L, 3, "position", b->p, 3);
    vec(L, 3, "rotation", b->q, 4);
    vec(L, 3, "velocity", b->v, 3);
    vec(L, 3, "spin", b->w, 3);
    fk_body_update(b);
    fk_world_wake(w, b);
    return 0;
}

/* world:move(id, {dx, dy, dz}, dt) -> position, grounded (characters) */
static int l_move(lua_State *L) {
    fk_world *w = world_arg(L);
    fk_body *b = body_arg(L, w);
    if (b->kind != FK_BODY_CHARACTER) return luaL_error(L, "physics: body %d is not a character", (int)b->id);
    luaL_checktype(L, 3, LUA_TTABLE);
    float d[3] = {0, 0, 0};
    for (int i = 0; i < 3; i++) {
        lua_rawgeti(L, 3, i + 1);
        d[i] = num(L, -1, "move");
        lua_pop(L, 1);
    }
    fk_world_move(w, b, d, (float)luaL_checknumber(L, 4));
    push3(L, b->p, 3);
    lua_pushboolean(L, b->grounded);
    return 2;
}

/* world:step(dt[, min_impulse]) -> the new touches: {{a, b, point, normal, impulse}, ...} */
static int l_step(lua_State *L) {
    fk_world *w = world_arg(L);
    float dt = (float)luaL_checknumber(L, 2), min = (float)luaL_optnumber(L, 3, 1e30);
    int n;
    const fk_impact *m = fk_world_step(w, dt, min, &n);
    lua_createtable(L, n, 0);
    for (int i = 0; i < n; i++) {
        lua_createtable(L, 0, 5);
        lua_pushinteger(L, m[i].a);
        lua_setfield(L, -2, "a");
        lua_pushinteger(L, m[i].b);
        lua_setfield(L, -2, "b");
        push3(L, m[i].point, 3);
        lua_setfield(L, -2, "point");
        push3(L, m[i].normal, 3);
        lua_setfield(L, -2, "normal");
        lua_pushnumber(L, m[i].impulse);
        lua_setfield(L, -2, "impulse");
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

/* world:gravity([{x, y, z}]) -> the world's gravity (setting it wakes every body) */
static int l_gravity(lua_State *L) {
    fk_world *w = world_arg(L);
    if (!lua_isnoneornil(L, 2)) {
        luaL_checktype(L, 2, LUA_TTABLE);
        float g[3];
        for (int i = 0; i < 3; i++) {
            lua_rawgeti(L, 2, i + 1);
            g[i] = num(L, -1, "gravity");
            lua_pop(L, 1);
        }
        fk_world_gravity(w, g);
    }
    push3(L, fk_world_get_gravity(w), 3);
    return 1;
}

static int l_count(lua_State *L) {
    lua_pushinteger(L, fk_world_count(world_arg(L)));
    return 1;
}

/* Saving ----------------------------------------------------------------------------------------------- */

#define NUM_FIELDS(X)                                                                                          \
    X(radius, shape.radius) X(inv_mass, inv_mass) X(friction, friction) X(restitution, restitution)            \
    X(step, step) X(slope_cos, slope_cos) X(push_mass, push_mass)
#define VEC_FIELDS(X)                                                                                          \
    X(half, shape.half, 3) X(p, p, 3) X(q, q, 4) X(v, v, 3) X(w, w, 3) X(inv_inertia, inv_inertia, 3) X(gravity, gravity, 3)

static int l_state(lua_State *L) {
    fk_world *w = world_arg(L);
    lua_createtable(L, 0, 3);
    lua_pushinteger(L, fk_world_next_id(w));
    lua_setfield(L, -2, "next_id");
    push3(L, fk_world_get_gravity(w), 3);
    lua_setfield(L, -2, "gravity");
    int n = fk_world_count(w);
    lua_createtable(L, n, 0);
    for (int i = 0; i < n; i++) {
        const fk_body *b = &fk_world_bodies(w)[i];
        lua_createtable(L, 0, 20);
        lua_pushinteger(L, b->id);
        lua_setfield(L, -2, "id");
        lua_pushinteger(L, b->kind);
        lua_setfield(L, -2, "kind");
        lua_pushinteger(L, b->shape.type);
        lua_setfield(L, -2, "shape");
        lua_pushinteger(L, b->still);
        lua_setfield(L, -2, "still");
        lua_pushboolean(L, b->asleep);
        lua_setfield(L, -2, "asleep");
        lua_pushboolean(L, b->own_gravity);
        lua_setfield(L, -2, "own_gravity");
        lua_pushboolean(L, b->grounded);
        lua_setfield(L, -2, "grounded");
#define X(name, field) lua_pushnumber(L, b->field), lua_setfield(L, -2, #name);
        NUM_FIELDS(X)
#undef X
#define X(name, field, n) push3(L, b->field, n), lua_setfield(L, -2, #name);
        VEC_FIELDS(X)
#undef X
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "bodies");
    int nc;
    const fk_cached *c = fk_world_cache(w, &nc);
    lua_createtable(L, nc, 0);
    for (int i = 0; i < nc; i++) {
        lua_createtable(L, 6, 0);
        const lua_Number row[6] = {c[i].a, c[i].b, c[i].key, c[i].jn, c[i].jt[0], c[i].jt[1]};
        for (int k = 0; k < 6; k++) {
            if (k < 3) lua_pushinteger(L, (lua_Integer)row[k]);
            else lua_pushnumber(L, row[k]);
            lua_rawseti(L, -2, k + 1);
        }
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "cache");
    return 1;
}

static lua_Integer int_field(lua_State *L, int t, const char *name) {
    lua_getfield(L, t, name);
    int ok;
    lua_Integer v = lua_tointegerx(L, -1, &ok);
    if (!ok) luaL_error(L, "restore: '%s' must be an integer", name);
    lua_pop(L, 1);
    return v;
}

static bool bool_field(lua_State *L, int t, const char *name) {
    lua_getfield(L, t, name);
    bool v = lua_toboolean(L, -1);
    lua_pop(L, 1);
    return v;
}

/* Reads everything first and only then replaces the world, so a bad state leaves the world as it was. */
static int l_restore(lua_State *L) {
    fk_world *w = world_arg(L);
    luaL_checktype(L, 2, LUA_TTABLE);
    lua_Integer next = int_field(L, 2, "next_id");
    if (next < 1 || next > 0xffffffff) return luaL_error(L, "restore: 'next_id' is out of range");
    if (lua_getfield(L, 2, "bodies") != LUA_TTABLE) return luaL_error(L, "restore: 'bodies' must be a table");
    int bodies = lua_gettop(L), nb = (int)luaL_len(L, bodies);
    fk_body *list = lua_newuserdatauv(L, (size_t)(nb ? nb : 1) * sizeof *list, 0); /* freed by the collector */
    for (int i = 1; i <= nb; i++) {
        if (lua_rawgeti(L, bodies, i) != LUA_TTABLE) return luaL_error(L, "restore: body %d must be a table", i);
        int t = lua_gettop(L);
        fk_body *b = &list[i - 1];
        memset(b, 0, sizeof *b);
        lua_Integer id = int_field(L, t, "id"), kind = int_field(L, t, "kind"), shape = int_field(L, t, "shape");
        if (id < 1 || id >= next || (i > 1 && (uint32_t)id <= list[i - 2].id) || kind < FK_BODY_STATIC || kind > FK_BODY_CHARACTER ||
            shape < FK_SHAPE_SPHERE || shape > FK_SHAPE_BOX)
            return luaL_error(L, "restore: body %d has a bad id, kind or shape (ids must rise and stay below 'next_id')", i);
        b->id = (uint32_t)id, b->kind = (int)kind, b->shape.type = (int)shape;
        b->still = (int)int_field(L, t, "still");
        b->asleep = bool_field(L, t, "asleep"), b->own_gravity = bool_field(L, t, "own_gravity"), b->grounded = bool_field(L, t, "grounded");
#define X(name, field) b->field = opt(L, t, #name, 0);
        NUM_FIELDS(X)
#undef X
#define X(name, field, n) if (!vec(L, t, #name, b->field, n)) return luaL_error(L, "restore: body %d needs '%s'", i, #name);
        VEC_FIELDS(X)
#undef X
        lua_pop(L, 1);
    }
    if (lua_getfield(L, 2, "cache") != LUA_TTABLE) return luaL_error(L, "restore: 'cache' must be a table");
    int ct = lua_gettop(L), nc = (int)luaL_len(L, ct);
    fk_cached *cache = lua_newuserdatauv(L, (size_t)(nc ? nc : 1) * sizeof *cache, 0);
    for (int i = 0; i < nc; i++) {
        lua_Number row[6]; /* doubles: the ids and keys are 32-bit integers */
        if (lua_rawgeti(L, ct, i + 1) != LUA_TTABLE || luaL_len(L, -1) != 6) return luaL_error(L, "restore: a cache row must have 6 numbers");
        for (int k = 0; k < 6; k++) {
            lua_rawgeti(L, -1, k + 1);
            int ok;
            row[k] = lua_tonumberx(L, -1, &ok);
            if (!ok || !isfinite(row[k]) || (k < 3 && !(row[k] >= 0 && row[k] <= 4294967295.0)))
                return luaL_error(L, "restore: a cache row must have 6 numbers");
            lua_pop(L, 1);
        }
        lua_pop(L, 1);
        cache[i] = (fk_cached){(uint32_t)row[0], (uint32_t)row[1], (uint32_t)row[2], (float)row[3], {(float)row[4], (float)row[5]}};
    }
    float gravity[3];
    bool has_gravity = vec(L, 2, "gravity", gravity, 3);
    fk_world_clear(w, (uint32_t)next);
    if (has_gravity) fk_world_gravity(w, gravity);
    for (int i = 0; i < nb; i++) fk_world_put(w, &list[i]); /* cannot fail: the ids were checked above */
    fk_world_put_cache(w, cache, nc);
    return 0;
}

/* world:terrain{origin = {x0, z0}, cell, heights = {(n + 1)^2 numbers, row by row from origin}, friction} sets the
   ground (terrain-streaming spec); world:terrain(nil) removes it. Not part of world:state(): rebuild it after a load. */
static int l_terrain(lua_State *L) {
    fk_world *w = world_arg(L);
    if (lua_isnoneornil(L, 2)) {
        fk_world_terrain(w, 0, 0, 0, 0, NULL, 0.8f);
        return 0;
    }
    luaL_checktype(L, 2, LUA_TTABLE);
    float origin[2] = {0, 0};
    vec(L, 2, "origin", origin, 2);
    float cell = positive(L, 2, "cell", 1), friction = opt(L, 2, "friction", 0.8f);
    if (lua_getfield(L, 2, "heights") != LUA_TTABLE) return luaL_error(L, "physics: terrain 'heights' must be a table");
    int count = (int)luaL_len(L, -1), n = (int)sqrt((double)count) - 1;
    if (n < 1 || (n + 1) * (n + 1) != count) return luaL_error(L, "physics: terrain 'heights' must hold (n + 1)^2 numbers, n >= 1");
    float *h = lua_newuserdatauv(L, (size_t)count * sizeof *h, 0); /* freed by the collector */
    for (int i = 0; i < count; i++) {
        lua_rawgeti(L, -2, i + 1);
        h[i] = num(L, -1, "heights");
        lua_pop(L, 1);
    }
    fk_world_terrain(w, origin[0], origin[1], cell, n, h, friction);
    return 0;
}

/* world:digs({x, y, z, radius, ...}[, wake]): the dug spheres (voxel-terrain spec), replacing any before; wake: wake
   every body (a new dig) */
static int l_digs(lua_State *L) {
    fk_world *w = world_arg(L);
    luaL_checktype(L, 2, LUA_TTABLE);
    bool wake = lua_toboolean(L, 3); /* (before the scratch buffer goes onto the stack) */
    int n = (int)luaL_len(L, 2);
    if (n % 4 || n / 4 > 4096) return luaL_error(L, "physics: digs need x, y, z, radius each (at most 4096)");
    float *d = lua_newuserdatauv(L, (size_t)(n ? n : 1) * sizeof *d, 0);
    for (int i = 0; i < n; i++) {
        lua_rawgeti(L, 2, i + 1);
        d[i] = num(L, -1, "digs");
        lua_pop(L, 1);
        if (i % 4 == 3 && !(d[i] > 0)) return luaL_error(L, "physics: a dig's radius must be above 0");
    }
    fk_world_digs(w, d, n / 4, wake);
    return 0;
}

/* world:height(x, z) -> the terrain's height and normal (h, nx, ny, nz) there, or nil outside it */
static int l_height(lua_State *L) {
    fk_world *w = world_arg(L);
    float h, n[3];
    if (!fk_terrain_height(fk_world_get_terrain(w), (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3), &h, n)) return 0;
    lua_pushnumber(L, h);
    for (int i = 0; i < 3; i++) lua_pushnumber(L, n[i]);
    return 4;
}

void fk_lua_physics_open(lua_State *L) {
    static const luaL_Reg methods[] = {{"add", l_add},       {"character", l_character}, {"remove", l_remove},
                                       {"get", l_get},       {"set", l_set},             {"move", l_move},
                                       {"step", l_step},     {"count", l_count},         {"gravity", l_gravity},         {"state", l_state},
                                       {"restore", l_restore}, {"terrain", l_terrain},   {"height", l_height},
                                       {"digs", l_digs},
                                       {NULL, NULL}};
    luaL_newmetatable(L, "fk.world");
    lua_pushcfunction(L, l_gc);
    lua_setfield(L, -2, "__gc");
    luaL_newlib(L, methods);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    lua_createtable(L, 0, 1);
    lua_pushcfunction(L, l_world);
    lua_setfield(L, -2, "world");
}
