/* fk.anim: poses of glTF models for scripts. Sampling and blending run in C (anim/anim.c); blend trees and
   state machines are Lua (data/scripts/fk/anim.lua). Poses are presentation: they never change the simulation. */
#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "anim/anim.h"
#include "core/mat4.h"
#include "lauxlib.h"
#include "script/script.h"

typedef struct {
    fk_trs *trs;
    int count;
} lua_pose;

/* A scratch pose and node matrices shared by all calls (scripts run on one thread). */
static fk_trs *scratch;
static float *globals;
static int scratch_count;

static void ensure_scratch(int n) {
    if (n <= scratch_count) return;
    fk_trs *t = realloc(scratch, (size_t)n * sizeof *t);
    float *g = realloc(globals, (size_t)n * 16 * sizeof *g);
    if (!t || !g) abort(); /* out of memory while animating: nothing sensible to continue with */
    scratch = t, globals = g, scratch_count = n;
}

/* The pose at arg and its model; a model reloaded with a different node count resets the pose. */
static lua_pose *pose_arg(lua_State *L, int arg, fk_model **model) {
    lua_pose *p = luaL_checkudata(L, arg, "fk.pose");
    lua_getiuservalue(L, arg, 1);
    *model = fk_lua_model_arg(L, -1);
    lua_pop(L, 1);
    if ((*model)->node_count != p->count) {
        fk_trs *t = realloc(p->trs, (size_t)((*model)->node_count + 1) * sizeof *t);
        if (!t) luaL_error(L, "out of memory");
        p->trs = t, p->count = (*model)->node_count;
        fk_pose_rest(*model, p->trs);
    }
    return p;
}

static int index_arg(lua_State *L, int arg, int count, int (*find)(const fk_model *, const char *), const fk_model *m,
                     const char *what) {
    int i;
    if (lua_type(L, arg) == LUA_TSTRING) {
        i = find(m, lua_tostring(L, arg));
        if (i < 0) luaL_error(L, "the model has no %s named '%s'", what, lua_tostring(L, arg));
    } else {
        lua_Integer k = luaL_checkinteger(L, arg);
        if (k < 1 || k > count) luaL_error(L, "%s number %d is out of range (1 to %d)", what, (int)k, count);
        i = (int)k - 1;
    }
    return i;
}

static int clip_arg(lua_State *L, int arg, const fk_model *m) { return index_arg(L, arg, m->clip_count, fk_model_clip, m, "clip"); }
static int node_arg(lua_State *L, int arg, const fk_model *m) { return index_arg(L, arg, m->node_count, fk_model_node, m, "node"); }

static float weight_arg(lua_State *L, int arg) {
    lua_Number w = luaL_optnumber(L, arg, 1);
    luaL_argcheck(L, w >= 0 && w <= 1, arg, "the weight must be from 0 to 1");
    return (float)w;
}

static float finite_arg(lua_State *L, int arg) {
    lua_Number t = luaL_checknumber(L, arg);
    luaL_argcheck(L, isfinite(t), arg, "must be a finite number");
    return (float)t;
}

/* fk.anim.pose(model): a pose in the model's rest pose. */
static int l_pose(lua_State *L) {
    fk_model *m = fk_lua_model_arg(L, 1);
    luaL_argcheck(L, m != NULL, 1, "a model from fk.gfx.model");
    lua_pose *p = lua_newuserdatauv(L, sizeof *p, 1);
    p->trs = malloc((size_t)(m->node_count + 1) * sizeof *p->trs);
    p->count = m->node_count;
    if (!p->trs) return luaL_error(L, "out of memory");
    luaL_setmetatable(L, "fk.pose");
    lua_pushvalue(L, 1);
    lua_setiuservalue(L, -2, 1); /* keeps the model alive */
    fk_pose_rest(m, p->trs);
    return 1;
}

static int l_pose_gc(lua_State *L) {
    lua_pose *p = luaL_checkudata(L, 1, "fk.pose");
    free(p->trs);
    p->trs = NULL;
    return 0;
}

static int l_rest(lua_State *L) {
    fk_model *m = NULL;
    lua_pose *p = pose_arg(L, 1, &m);
    fk_pose_rest(m, p->trs);
    lua_settop(L, 1);
    return 1;
}

/* pose:sample(clip, time[, weight]): the clip at time (seconds, clamped to the clip), blended in by weight. */
static int l_sample(lua_State *L) {
    fk_model *m = NULL;
    lua_pose *p = pose_arg(L, 1, &m);
    int clip = clip_arg(L, 2, m);
    float t = finite_arg(L, 3), w = weight_arg(L, 4);
    if (w >= 1) {
        fk_clip_sample(m, clip, t, p->trs);
    } else {
        ensure_scratch(p->count);
        memcpy(scratch, p->trs, (size_t)p->count * sizeof *scratch);
        fk_clip_sample(m, clip, t, scratch);
        fk_pose_blend(p->trs, scratch, w, p->trs, p->count);
    }
    lua_settop(L, 1);
    return 1;
}

/* pose:add(clip, time[, weight]): adds the clip's difference from the rest pose (an additive layer). */
static int l_add(lua_State *L) {
    fk_model *m = NULL;
    lua_pose *p = pose_arg(L, 1, &m);
    int clip = clip_arg(L, 2, m);
    float t = finite_arg(L, 3), w = weight_arg(L, 4);
    ensure_scratch(p->count);
    fk_pose_rest(m, scratch);
    fk_clip_sample(m, clip, t, scratch);
    fk_pose_add(m, p->trs, scratch, w);
    lua_settop(L, 1);
    return 1;
}

/* pose:blend(other, weight): moves this pose towards another pose of the same model. */
static int l_blend(lua_State *L) {
    fk_model *m = NULL, *mo = NULL;
    lua_pose *p = pose_arg(L, 1, &m), *o = pose_arg(L, 2, &mo);
    luaL_argcheck(L, m == mo, 2, "a pose of the same model");
    fk_pose_blend(p->trs, o->trs, weight_arg(L, 3), p->trs, p->count);
    lua_settop(L, 1);
    return 1;
}

/* pose:copy(other): this pose becomes a copy of another pose of the same model. */
static int l_copy(lua_State *L) {
    fk_model *m = NULL, *mo = NULL;
    lua_pose *p = pose_arg(L, 1, &m), *o = pose_arg(L, 2, &mo);
    luaL_argcheck(L, m == mo, 2, "a pose of the same model");
    memcpy(p->trs, o->trs, (size_t)p->count * sizeof *p->trs);
    lua_settop(L, 1);
    return 1;
}

/* pose:rotate(node, {x, y, z}, angle): turns a node about an axis in its own space (springs, look-at). */
static int l_rotate(lua_State *L) {
    fk_model *m = NULL;
    lua_pose *p = pose_arg(L, 1, &m);
    int n = node_arg(L, 2, m);
    luaL_checktype(L, 3, LUA_TTABLE);
    float axis[3], angle = finite_arg(L, 4);
    for (int k = 0; k < 3; k++) {
        lua_rawgeti(L, 3, k + 1);
        int ok;
        lua_Number v = lua_tonumberx(L, -1, &ok);
        if (!ok || !isfinite(v)) return luaL_error(L, "rotate: the axis must be 3 finite numbers");
        axis[k] = (float)v;
        lua_pop(L, 1);
    }
    float len = sqrtf(axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2]);
    if (len < 1e-6f) return luaL_error(L, "rotate: the axis must not be zero");
    float s = sinf(angle / 2) / len, *r = p->trs[n].r;
    float q[4] = {axis[0] * s, axis[1] * s, axis[2] * s, cosf(angle / 2)};
    float out[4] = {r[3] * q[0] + r[0] * q[3] + r[1] * q[2] - r[2] * q[1], r[3] * q[1] - r[0] * q[2] + r[1] * q[3] + r[2] * q[0],
                    r[3] * q[2] + r[0] * q[1] - r[1] * q[0] + r[2] * q[3], r[3] * q[3] - r[0] * q[0] - r[1] * q[1] - r[2] * q[2]};
    memcpy(r, out, sizeof out);
    lua_settop(L, 1);
    return 1;
}

/* pose:scale(node, s): scales a node and everything below it (0 hides it, e.g. the head seen from inside). */
static int l_scale(lua_State *L) {
    fk_model *m = NULL;
    lua_pose *p = pose_arg(L, 1, &m);
    int n = node_arg(L, 2, m);
    float s = finite_arg(L, 3);
    for (int k = 0; k < 3; k++) p->trs[n].s[k] = s;
    lua_settop(L, 1);
    return 1;
}

/* pose:global(node): the node's model-space matrix (16 numbers), for attaching things to it. */
static int l_global(lua_State *L) {
    fk_model *m = NULL;
    lua_pose *p = pose_arg(L, 1, &m);
    int n = node_arg(L, 2, m);
    ensure_scratch(p->count);
    fk_pose_globals(m, p->trs, globals);
    lua_createtable(L, 16, 0);
    for (int i = 0; i < 16; i++) {
        lua_pushnumber(L, globals[n * 16 + i]);
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

/* pose:node(name): the node's number, or nil. */
static int l_node(lua_State *L) {
    fk_model *m = NULL;
    pose_arg(L, 1, &m);
    int n = fk_model_node(m, luaL_checkstring(L, 2));
    if (n < 0) lua_pushnil(L);
    else lua_pushinteger(L, n + 1);
    return 1;
}

const float *fk_lua_pose_globals(lua_State *L, int arg, const fk_model *model) {
    fk_model *m = NULL;
    lua_pose *p = pose_arg(L, arg, &m);
    if (m != model) luaL_error(L, "draw: the pose belongs to another model");
    ensure_scratch(p->count);
    fk_pose_globals(m, p->trs, globals);
    return globals;
}

void fk_lua_anim_open(lua_State *L) {
    static const luaL_Reg methods[] = {{"rest", l_rest},     {"sample", l_sample}, {"add", l_add},
                                       {"blend", l_blend},   {"copy", l_copy},     {"rotate", l_rotate}, {"scale", l_scale},
                                       {"global", l_global}, {"node", l_node},     {NULL, NULL}};
    luaL_newmetatable(L, "fk.pose");
    lua_pushcfunction(L, l_pose_gc);
    lua_setfield(L, -2, "__gc");
    luaL_newlib(L, methods);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    lua_createtable(L, 0, 1);
    lua_pushcfunction(L, l_pose);
    lua_setfield(L, -2, "pose");
}
