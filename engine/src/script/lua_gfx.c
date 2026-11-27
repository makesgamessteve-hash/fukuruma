/* fk.gfx: meshes, camera, lights, materials, overlay and graphics settings for scripts. Everything is
   validated (mods are scripts too); without rendering, calls only validate and record. */
#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "core/jobs.h"
#include "fx/particles.h"
#include "gen/sky.h"
#include "gfx/frame.h"
#include "gfx/gfx.h"
#include "lauxlib.h"
#include "platform/platform.h"
#include "script/script.h"

#define FK_MAX_VERTICES (1 << 20)

static bool rendering;

static lua_Integer field_table(lua_State *L, const char *name) {
    if (lua_getfield(L, 1, name) != LUA_TTABLE) luaL_error(L, "mesh: '%s' must be a table", name);
    return luaL_len(L, -1);
}

static float number_at(lua_State *L, int table, lua_Integer i, const char *what) {
    lua_rawgeti(L, table, i);
    int ok;
    lua_Number v = lua_tonumberx(L, -1, &ok);
    if (!ok || !isfinite(v)) luaL_error(L, "%s[%d] is not a finite number", what, (int)i);
    lua_pop(L, 1);
    return (float)v;
}

static void matrix_arg(lua_State *L, int arg, float m[16], const char *what) {
    luaL_checktype(L, arg, LUA_TTABLE);
    if (luaL_len(L, arg) != 16) luaL_error(L, "%s: the matrix must have 16 numbers", what);
    for (int i = 0; i < 16; i++) m[i] = number_at(L, arg, i + 1, "matrix");
}

static double lua_Number_at(lua_State *L, int t, int i) {
    lua_rawgeti(L, t, i);
    double v = lua_tonumber(L, -1);
    lua_pop(L, 1);
    return v;
}

/* The frame's floating origin (draw axes, metres): every world position coming in has it subtracted in double before
   it becomes a float, and the camera adds it back, so the picture is the same but far from the origin of the draw
   axes (a Jump Ship 30,000 km up) its geometry keeps centimetre precision. */
static double origin[3];

static double world_at(lua_State *L, int t, int i, int axis) {
    lua_rawgeti(L, t, i);
    int ok;
    lua_Number v = lua_tonumberx(L, -1, &ok);
    lua_pop(L, 1);
    if (!ok || !isfinite(v)) luaL_error(L, "the position's number %d is not a finite number", i);
    return v - origin[axis];
}

/* A model matrix with the origin taken out of its translation. */
static void model_arg(lua_State *L, int arg, float m[16], const char *what) {
    matrix_arg(L, arg, m, what);
    for (int k = 0; k < 3; k++) m[12 + k] = (float)world_at(L, arg, 13 + k, k);
}

/* t[name] = {x, y, z}, a place in the draw axes, with the origin taken out (def when absent). */
static void field_world(lua_State *L, int t, const char *name, float out[3], const float def[3], const char *what) {
    int type = lua_getfield(L, t, name);
    if (type == LUA_TNIL) {
        for (int k = 0; k < 3; k++) out[k] = (float)(def[k] - origin[k]);
    } else {
        if (type != LUA_TTABLE || luaL_len(L, -1) != 3) luaL_error(L, "%s: '%s' must be a table of 3 numbers", what, name);
        for (int k = 0; k < 3; k++) out[k] = (float)world_at(L, lua_gettop(L), k + 1, k);
    }
    lua_pop(L, 1);
}

/* fk.gfx.origin(x, y, z): the frame's floating origin (see above); live particles move with it. */
static int l_origin(lua_State *L) {
    double o[3];
    for (int k = 0; k < 3; k++) {
        o[k] = luaL_checknumber(L, k + 1);
        luaL_argcheck(L, isfinite(o[k]), k + 1, "origin: a finite number");
    }
    fk_particles_shift((float)(origin[0] - o[0]), (float)(origin[1] - o[1]), (float)(origin[2] - o[2]));
    memcpy(origin, o, sizeof origin);
    return 0;
}

/* Reads t[name] as a number in [lo, hi], or def when absent. */
static float field_number(lua_State *L, int t, const char *name, float def, float lo, float hi, const char *what) {
    lua_getfield(L, t, name);
    int ok = 1;
    lua_Number v = lua_isnil(L, -1) ? def : lua_tonumberx(L, -1, &ok);
    lua_pop(L, 1);
    if (!ok || !(v >= lo && v <= hi)) luaL_error(L, "%s: '%s' must be a number from %f to %f", what, name, (double)lo, (double)hi);
    return (float)v;
}

/* Reads t[name] as {x, y, z} with components in [lo, hi], or def when absent. */
static void field_vec3(lua_State *L, int t, const char *name, float out[3], const float def[3], float lo, float hi, const char *what) {
    int type = lua_getfield(L, t, name);
    if (type == LUA_TNIL) memcpy(out, def, 3 * sizeof(float));
    else {
        if (type != LUA_TTABLE || luaL_len(L, -1) != 3) luaL_error(L, "%s: '%s' must be a table of 3 numbers", what, name);
        for (int i = 0; i < 3; i++) {
            out[i] = number_at(L, lua_gettop(L), i + 1, name);
            if (!(out[i] >= lo && out[i] <= hi)) luaL_error(L, "%s: '%s' values must be from %f to %f", what, name, (double)lo, (double)hi);
        }
    }
    lua_pop(L, 1);
}

static void keep_alive(lua_State *L, int arg) { /* the mesh must outlive this frame's rendering */
    lua_getfield(L, LUA_REGISTRYINDEX, "fk.frame_meshes");
    lua_pushvalue(L, arg);
    lua_rawseti(L, -2, (lua_Integer)luaL_len(L, -2) + 1);
    lua_pop(L, 1);
}

/* Skies ---------------------------------------------------------------------------------------------------- */

typedef struct {
    uint64_t seed;
    double pos[3], radius;
    int size, stars;
    float *rgb; /* the baked faces until uploaded */
    uint32_t job;
    fk_texture tex;
} sky_map;

static void bake(void *data) {
    sky_map *m = data;
    m->stars = fk_sky_bake(m->seed, m->pos, m->radius, m->size, m->rgb);
}

/* fk.gfx.starfield(seed, {x, y, z}, radius, size): bakes the sky seen from a point of the galaxy in the background.
   map:ready(); map:stars() waits and gives the number of stars drawn. */
static int l_starfield(lua_State *L) {
    sky_map *m = lua_newuserdatauv(L, sizeof *m, 0);
    memset(m, 0, sizeof *m);
    luaL_setmetatable(L, "fk.sky_map");
    m->seed = (uint64_t)luaL_checkinteger(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    for (int i = 0; i < 3; i++) m->pos[i] = number_at(L, 2, i + 1, "starfield");
    m->radius = luaL_checknumber(L, 3);
    m->size = (int)luaL_optinteger(L, 4, 256);
    luaL_argcheck(L, m->radius > 0 && m->radius <= 500, 3, "the radius must be from 0 to 500 light-years");
    luaL_argcheck(L, m->size >= 8 && m->size <= 1024, 4, "the size must be from 8 to 1024");
    m->rgb = malloc((size_t)6 * m->size * m->size * 3 * sizeof *m->rgb);
    if (!m->rgb) return luaL_error(L, "out of memory");
    m->job = fk_jobs_submit(bake, m);
    return 1;
}

static sky_map *finished(lua_State *L, int arg) {
    sky_map *m = luaL_checkudata(L, arg, "fk.sky_map");
    if (m->rgb) { /* once baked: upload when rendering, then the pixels can go */
        fk_jobs_wait(m->job);
        if (rendering) fk_gfx_cubemap_upload(&m->tex, m->rgb, m->size);
        free(m->rgb);
        m->rgb = NULL;
    }
    return m;
}

static int l_sky_ready(lua_State *L) {
    sky_map *m = luaL_checkudata(L, 1, "fk.sky_map");
    lua_pushboolean(L, !m->rgb || fk_jobs_done(m->job));
    return 1;
}

static int l_sky_stars(lua_State *L) {
    lua_pushinteger(L, finished(L, 1)->stars);
    return 1;
}

static int l_sky_gc(lua_State *L) {
    sky_map *m = luaL_checkudata(L, 1, "fk.sky_map");
    if (m->rgb) fk_jobs_wait(m->job); /* the job writes into rgb */
    free(m->rgb);
    m->rgb = NULL;
    if (rendering && m->tex.id) fk_gfx_texture_destroy(&m->tex);
    return 0;
}

/* fk.gfx.sky(map, {strength = 1, rotation = {x, y, z, w}}) shows a sky map where nothing is drawn; fk.gfx.sky(nil)
   removes it. The rotation turns the world's directions into the map's (galaxy) directions. */
static int l_sky(lua_State *L) {
    fk_frame *f = fk_frame_get();
    if (lua_isnoneornil(L, 1)) {
        f->sky_map = NULL;
        lua_pushnil(L);
        lua_setfield(L, LUA_REGISTRYINDEX, "fk.sky"); /* no longer kept alive */
        return 0;
    }
    sky_map *m = finished(L, 1);
    f->sky_map = &m->tex;
    lua_pushvalue(L, 1);
    lua_setfield(L, LUA_REGISTRYINDEX, "fk.sky");
    float q[4] = {0, 0, 0, 1};
    f->sky_strength = 1;
    if (!lua_isnoneornil(L, 2)) {
        luaL_checktype(L, 2, LUA_TTABLE);
        f->sky_strength = field_number(L, 2, "strength", 1, 0, 1000, "sky");
        if (lua_getfield(L, 2, "rotation") != LUA_TNIL) {
            if (!lua_istable(L, -1) || luaL_len(L, -1) != 4) return luaL_error(L, "sky: 'rotation' must be a quaternion {x, y, z, w}");
            for (int i = 0; i < 4; i++) q[i] = number_at(L, lua_gettop(L), i + 1, "rotation");
        }
        lua_pop(L, 1);
    }
    float x = q[0], y = q[1], z = q[2], w = q[3], *r = f->sky_rotation;
    r[0] = 1 - 2 * (y * y + z * z), r[1] = 2 * (x * y + z * w), r[2] = 2 * (x * z - y * w);
    r[3] = 2 * (x * y - z * w), r[4] = 1 - 2 * (x * x + z * z), r[5] = 2 * (y * z + x * w);
    r[6] = 2 * (x * z + y * w), r[7] = 2 * (y * z - x * w), r[8] = 1 - 2 * (x * x + y * y);
    return 0;
}

void fk_script_frame_begin(lua_State *L) {
    lua_newtable(L);
    lua_setfield(L, LUA_REGISTRYINDEX, "fk.frame_meshes");
    fk_frame_begin();
}

/* fk.gfx.mesh{ positions = {x, y, z, ...}, colors = {r, g, b, ...} (sRGB), indices = {1, 2, 3, ...},
   normals = {...} (optional: computed from the triangles), uvs = {u, v, ...} (optional) } */
static int l_mesh(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_settop(L, 1);
    lua_Integer np = field_table(L, "positions"), nc = field_table(L, "colors"), ni = field_table(L, "indices");
    int nt = lua_getfield(L, 1, "normals"), nu = lua_getfield(L, 1, "uvs");
    if (np == 0 || np % 3) return luaL_error(L, "mesh: positions must hold x, y, z for at least one vertex");
    if (nc != np) return luaL_error(L, "mesh: colors must hold r, g, b for every vertex");
    if (nt != LUA_TNIL && (nt != LUA_TTABLE || luaL_len(L, 5) != np)) return luaL_error(L, "mesh: normals must hold x, y, z for every vertex");
    if (nu != LUA_TNIL && (nu != LUA_TTABLE || luaL_len(L, 6) != np / 3 * 2)) return luaL_error(L, "mesh: uvs must hold u, v for every vertex");
    if (ni == 0 || ni % 3) return luaL_error(L, "mesh: indices must describe whole triangles");
    lua_Integer nv = np / 3;
    if (nv > FK_MAX_VERTICES || ni > 3 * FK_MAX_VERTICES) return luaL_error(L, "mesh: too large");
    /* Scratch buffers are userdata, so an error in the middle does not leak them. */
    fk_vertex *v = lua_newuserdatauv(L, (size_t)nv * sizeof *v, 0);
    uint32_t *idx = lua_newuserdatauv(L, (size_t)ni * sizeof(uint32_t), 0);
    memset(v, 0, (size_t)nv * sizeof *v);
    for (lua_Integer i = 0; i < nv; i++) {
        for (int k = 0; k < 3; k++) {
            v[i].position[k] = number_at(L, 2, i * 3 + k + 1, "positions");
            v[i].color[k] = number_at(L, 3, i * 3 + k + 1, "colors");
            if (nt == LUA_TTABLE) v[i].normal[k] = number_at(L, 5, i * 3 + k + 1, "normals");
        }
        for (int k = 0; nu == LUA_TTABLE && k < 2; k++) v[i].uv[k] = number_at(L, 6, i * 2 + k + 1, "uvs");
        v[i].tangent[0] = v[i].tangent[3] = v[i].weights[0] = 1;
    }
    for (lua_Integer i = 0; i < ni; i++) {
        lua_rawgeti(L, 4, i + 1);
        int ok;
        lua_Integer x = lua_tointegerx(L, -1, &ok);
        if (!ok || x < 1 || x > nv) return luaL_error(L, "mesh: indices[%d] must be a vertex number from 1 to %d", (int)i + 1, (int)nv);
        idx[i] = (uint32_t)(x - 1);
        lua_pop(L, 1);
    }
    if (nt != LUA_TTABLE) fk_mesh_normals(v, (int)nv, idx, (int)ni);
    fk_mesh *m = lua_newuserdatauv(L, sizeof *m, 0);
    memset(m, 0, sizeof *m);
    m->count = (int)ni;
    if (rendering) fk_gfx_mesh_create(m, v, (int)nv, idx, (int)ni);
    luaL_setmetatable(L, "fk.mesh");
    return 1;
}

void fk_lua_push_mesh(lua_State *L, const fk_vertex *v, int nv, const uint32_t *idx, int ni) {
    fk_mesh *m = lua_newuserdatauv(L, sizeof *m, 0);
    memset(m, 0, sizeof *m);
    m->count = ni;
    if (rendering) fk_gfx_mesh_create(m, v, nv, idx, ni);
    luaL_setmetatable(L, "fk.mesh");
}

/* fk.gfx.instances{x, y, z, scale, yaw, brightness, sway phase, sway, ...}: instances for fk.gfx.draw's 'instances'
   option, eight numbers each (see fk_instances). */
static int l_instances(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_Integer n = luaL_len(L, 1);
    if (n % FK_INSTANCE_FLOATS || n / FK_INSTANCE_FLOATS > 1000000) return luaL_error(L, "instances: eight numbers per instance");
    float *data = lua_newuserdatauv(L, (size_t)(n ? n : 1) * sizeof *data, 0); /* scratch: freed by the collector */
    for (lua_Integer i = 0; i < n; i++) {
        lua_rawgeti(L, 1, i + 1);
        int ok;
        lua_Number v = lua_tonumberx(L, -1, &ok);
        if (i % FK_INSTANCE_FLOATS < 3) v -= origin[i % FK_INSTANCE_FLOATS]; /* the place, with the origin out */
        data[i] = (float)v;
        if (!ok || !isfinite(data[i])) return luaL_error(L, "instances: number %d is not a finite number", (int)i + 1);
        lua_pop(L, 1);
    }
    fk_instances *in = lua_newuserdatauv(L, sizeof *in, 0);
    memset(in, 0, sizeof *in);
    luaL_setmetatable(L, "fk.instances");
    if (rendering && n) fk_gfx_instances_create(in, data, (int)(n / FK_INSTANCE_FLOATS));
    in->count = (int)(n / FK_INSTANCE_FLOATS);
    return 1;
}

static int l_instances_gc(lua_State *L) {
    fk_instances *in = luaL_checkudata(L, 1, "fk.instances");
    if (in->vbo) fk_gfx_instances_destroy(in);
    return 0;
}

/* fk.gfx.wind{direction = {x, z}, strength, time}: how instanced plants sway (presentation time, seconds). */
static int l_wind(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    fk_frame *f = fk_frame_get();
    float dir[2] = {1, 0};
    if (lua_getfield(L, 1, "direction") == LUA_TTABLE) {
        for (int i = 0; i < 2; i++) {
            lua_rawgeti(L, -1, i + 1);
            dir[i] = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
    float len = sqrtf(dir[0] * dir[0] + dir[1] * dir[1]);
    if (len < 1e-6f) return luaL_error(L, "wind: 'direction' must not be zero");
    float strength = field_number(L, 1, "strength", 1, 0, 50, "wind");
    f->wind[0] = dir[0] / len * strength, f->wind[1] = dir[1] / len * strength;
    f->wind[2] = 0, f->wind[3] = (float)fmod(field_number(L, 1, "time", 0, 0, 1e9f, "wind"), 3600.0);
    return 0;
}

static int l_mesh_gc(lua_State *L) {
    fk_mesh *m = luaL_checkudata(L, 1, "fk.mesh");
    if (m->vao) fk_gfx_mesh_destroy(m);
    return 0;
}

static const float ZERO[3] = {0, 0, 0}, ONE[3] = {1, 1, 1};

/* fk.gfx.draw(mesh, matrix, { roughness, metalness, emission, texture }) or fk.gfx.draw(model, matrix, { pose }) */
static const char *const SLICES[] = {"near", "local", "planetary", "celestial", NULL};

/* opts.slice: the depth slice of this draw (default "local"). */
static int slice_option(lua_State *L, int opts) {
    if (lua_isnoneornil(L, opts)) return FK_SLICE_LOCAL;
    luaL_checktype(L, opts, LUA_TTABLE);
    int slice;
    lua_getfield(L, opts, "slice");
    if (lua_isnil(L, -1)) slice = FK_SLICE_LOCAL;
    else {
        const char *name = lua_tostring(L, -1);
        for (slice = 0; name && SLICES[slice] && strcmp(SLICES[slice], name); slice++) {}
        if (!name || !SLICES[slice]) return luaL_error(L, "draw: 'slice' must be near, local, planetary or celestial");
    }
    lua_pop(L, 1);
    return slice;
}

static int l_draw(lua_State *L) {
    float model[16];
    fk_frame_get()->slice = slice_option(L, 3);
    fk_model *mdl = fk_lua_model_arg(L, 1);
    if (mdl) {
        model_arg(L, 2, model, "draw");
        const float *globals = NULL;
        if (!lua_isnoneornil(L, 3)) {
            luaL_checktype(L, 3, LUA_TTABLE);
            if (lua_getfield(L, 3, "pose") != LUA_TNIL) globals = fk_lua_pose_globals(L, lua_gettop(L), mdl);
            lua_pop(L, 1);
        }
        keep_alive(L, 1);
        fk_lua_draw_model(mdl, model, globals);
        fk_frame_get()->slice = FK_SLICE_LOCAL;
        return 0;
    }
    fk_mesh *m = luaL_checkudata(L, 1, "fk.mesh");
    model_arg(L, 2, model, "draw");
    fk_material mat;
    fk_material_default(&mat);
    if (!lua_isnoneornil(L, 3)) {
        luaL_checktype(L, 3, LUA_TTABLE);
        mat.roughness = field_number(L, 3, "roughness", 0.6f, 0, 1, "draw");
        mat.metalness = field_number(L, 3, "metalness", 0, 0, 1, "draw");
        field_vec3(L, 3, "emission", mat.emission, ZERO, 0, 1000, "draw");
        float color[3];
        lua_getfield(L, 3, "one_sided");
        mat.one_sided = lua_toboolean(L, -1);
        lua_getfield(L, 3, "emissive_colors");
        mat.emissive_colors = lua_toboolean(L, -1);
        lua_pop(L, 2);
        mat.clouds = field_number(L, 3, "clouds", 0, 0, 1, "draw");
        if (lua_getfield(L, 3, "terrain") == LUA_TTABLE) { /* {origin, up, wet, snow, dust} */
            int t = lua_gettop(L);
            static const float UP[3] = {0, 1, 0};
            mat.terrain = (int)field_number(L, t, "quality", 3, 1, 3, "draw terrain");
            field_vec3(L, t, "origin", mat.terrain_origin, ZERO, -1e6f, 1e6f, "draw terrain");
            field_vec3(L, t, "up", mat.terrain_up, UP, -1, 1, "draw terrain");
            mat.weather[0] = field_number(L, t, "wet", 0, 0, 1, "draw terrain");
            mat.weather[1] = field_number(L, t, "snow", 0, 0, 1, "draw terrain");
            mat.weather[2] = field_number(L, t, "dust", 0, 0, 1, "draw terrain");
            if (lua_getfield(L, t, "digs") == LUA_TTABLE) { /* {x, y, z, r, ...}: the first 16 */
                int n = (int)luaL_len(L, -1) / 4;
                mat.ndigs = n > 16 ? 16 : n;
                for (int i = 0; i < 4 * mat.ndigs; i++) {
                    lua_rawgeti(L, -1, i + 1);
                    mat.digs[i / 4][i % 4] = (float)(luaL_checknumber(L, -1) - (i % 4 < 3 ? origin[i % 4] : 0));
                    lua_pop(L, 1);
                }
            }
            lua_pop(L, 1);
        }
        lua_pop(L, 1);
        field_vec3(L, 3, "color", color, ONE, 0, 1, "draw"); /* sRGB, multiplies the vertex colours */
        for (int i = 0; i < 3; i++) mat.base[i] = fk_srgb_to_linear(color[i]);
        if (lua_getfield(L, 3, "texture") != LUA_TNIL) {
            mat.base_tex = fk_lua_texture_arg(L, -1);
            if (!mat.base_tex) return luaL_error(L, "draw: 'texture' must be a texture from fk.gfx.texture");
            keep_alive(L, lua_gettop(L));
        }
        lua_pop(L, 1);
        if (lua_getfield(L, 3, "instances") != LUA_TNIL) {
            fk_instances *in = luaL_testudata(L, -1, "fk.instances");
            if (!in) return luaL_error(L, "draw: 'instances' must come from fk.gfx.instances");
            if (in->count == 0) { /* nothing to draw */
                lua_pop(L, 1);
                return 0;
            }
            mat.instances = in;
            keep_alive(L, lua_gettop(L));
        }
        lua_pop(L, 1);
    }
    keep_alive(L, 1);
    fk_frame_draw(m, model, &mat);
    fk_frame_get()->slice = FK_SLICE_LOCAL;
    return 0;
}

/* fk.gfx.slices{near = {n, f}, planetary = {n, f}, celestial = {n, f}}: the near and far planes (metres) of the
   depth slices; the local slice uses the camera's projection. Slices not named keep their planes. */
/* fk.gfx.atmosphere{centre, radius, top, height, rayleigh = {r, g, b}, mie, absorb = {r, g, b}} sets the air seen
   this frame (camera-relative world space, metres; set it every frame); fk.gfx.atmosphere(nil) removes it. */
static int l_atmosphere(lua_State *L) {
    fk_atmosphere *a = &fk_frame_get()->atmosphere;
    if (lua_isnoneornil(L, 1)) {
        a->on = false;
        return 0;
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    static const float ZERO3[3] = {0, 0, 0};
    field_world(L, 1, "centre", a->centre, ZERO3, "atmosphere");
    a->radius = field_number(L, 1, "radius", 1, 1e-6f, 1e30f, "atmosphere");
    a->top = field_number(L, 1, "top", a->radius * 1.01f, a->radius, 1e30f, "atmosphere");
    a->height = field_number(L, 1, "height", 8000, 1e-6f, 1e30f, "atmosphere");
    field_vec3(L, 1, "rayleigh", a->rayleigh, ZERO3, 0, 1e30f, "atmosphere");
    a->mie = field_number(L, 1, "mie", 0, 0, 1e30f, "atmosphere");
    field_vec3(L, 1, "absorb", a->absorb, ZERO3, 0, 1e30f, "atmosphere");
    float g[3];
    static const float GREY[3] = {0.3f, 0.3f, 0.3f};
    field_vec3(L, 1, "ground", g, GREY, 0, 1, "atmosphere"); /* sRGB */
    for (int k = 0; k < 3; k++) a->ground[k] = fk_srgb_to_linear(g[k]);
    a->cloud_steps = 0;
    if (lua_getfield(L, 1, "clouds") == LUA_TTABLE) { /* {bottom, top, cover, density, offset = {x, y, z}, steps} */
        int t = lua_gettop(L);
        a->cloud_bottom = field_number(L, t, "bottom", 1500, 0, 1e6f, "atmosphere clouds");
        a->cloud_top = field_number(L, t, "top", a->cloud_bottom + 2000, a->cloud_bottom + 1, 1e6f, "atmosphere clouds");
        a->cloud_cover = field_number(L, t, "cover", 0.5f, 0, 1, "atmosphere clouds");
        a->cloud_density = field_number(L, t, "density", 0.004f, 0, 1, "atmosphere clouds");
        field_vec3(L, t, "offset", a->cloud_offset, ZERO3, -1e9f, 1e9f, "atmosphere clouds");
        a->cloud_steps = (int)field_number(L, t, "steps", 24, 0, 64, "atmosphere clouds");
    }
    lua_pop(L, 1);
    a->fog_density = a->fog_height = 0;
    if (lua_getfield(L, 1, "fog") == LUA_TTABLE) { /* {density, height} */
        int t = lua_gettop(L);
        a->fog_density = field_number(L, t, "density", 0.0005f, 0, 1, "atmosphere fog");
        a->fog_height = field_number(L, t, "height", 150, 1, 1e5f, "atmosphere fog");
    }
    lua_pop(L, 1);
    a->on = true;
    return 0;
}

/* fk.gfx.water{centre, radius, deep = {r, g, b}, shallow, time, waves} (sRGB colours) or fk.gfx.water(nil): the sea
   (water spec), per frame */
static int l_water(lua_State *L) {
    fk_water *w = &fk_frame_get()->water;
    if (lua_isnoneornil(L, 1)) {
        w->on = false;
        return 0;
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    static const float ZERO3[3] = {0, 0, 0}, DEEP[3] = {0.02f, 0.1f, 0.16f}, SHALLOW[3] = {0.1f, 0.42f, 0.42f};
    field_world(L, 1, "centre", w->centre, ZERO3, "water");
    w->radius = field_number(L, 1, "radius", 1, 1e-6f, 1e30f, "water");
    float deep[3], shallow[3];
    field_vec3(L, 1, "deep", deep, DEEP, 0, 1, "water");
    field_vec3(L, 1, "shallow", shallow, SHALLOW, 0, 1, "water");
    for (int k = 0; k < 3; k++) w->deep[k] = fk_srgb_to_linear(deep[k]), w->shallow[k] = fk_srgb_to_linear(shallow[k]);
    w->time = (float)fmod(field_number(L, 1, "time", 0, 0, 1e9f, "water"), 3600.0);
    w->waves = field_number(L, 1, "waves", 0.6f, 0, 20, "water");
    w->on = true;
    return 0;
}

/* fk.gfx.stats() -> draws, triangles recorded so far this frame (budgets) */
static int l_stats(lua_State *L) {
    lua_pushinteger(L, fk_frame_get()->ndraws);
    lua_pushinteger(L, fk_frame_get()->triangles);
    return 2;
}

static int l_slices(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    fk_frame *f = fk_frame_get();
    for (int i = 0; SLICES[i]; i++) {
        if (i == FK_SLICE_LOCAL) continue;
        if (lua_getfield(L, 1, SLICES[i]) != LUA_TNIL) {
            if (!lua_istable(L, -1) || luaL_len(L, -1) != 2) return luaL_error(L, "slices: '%s' must be {near, far}", SLICES[i]);
            float n = number_at(L, lua_gettop(L), 1, SLICES[i]), far = number_at(L, lua_gettop(L), 2, SLICES[i]);
            if (!(n > 0 && far > n)) return luaL_error(L, "slices: '%s' needs 0 < near < far", SLICES[i]);
            f->slice_near[i] = n, f->slice_far[i] = far;
        }
        lua_pop(L, 1);
    }
    return 0;
}

static int l_overlay(lua_State *L) {
    fk_mesh *m = luaL_checkudata(L, 1, "fk.mesh");
    float matrix[16];
    matrix_arg(L, 2, matrix, "overlay");
    keep_alive(L, 1);
    fk_frame_overlay(m, matrix);
    return 0;
}

static int l_camera(lua_State *L) {
    fk_frame *f = fk_frame_get();
    matrix_arg(L, 1, f->view, "camera");
    for (int k = 0; k < 3; k++) { /* the origin back in: view * translation(origin), in double */
        double t = lua_Number_at(L, 1, 13 + k);
        for (int c = 0; c < 3; c++) t += lua_Number_at(L, 1, 1 + 4 * c + k) * origin[c];
        f->view[12 + k] = (float)t;
    }
    matrix_arg(L, 2, f->projection, "camera");
    return 0;
}

static void linear_times(float out[3], const float srgb[3], float intensity) {
    for (int i = 0; i < 3; i++) out[i] = fk_srgb_to_linear(srgb[i]) * intensity;
}

static int l_sun(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    fk_frame *f = fk_frame_get();
    float dir[3], color[3];
    field_vec3(L, 1, "direction", dir, f->sun_dir, -1e6f, 1e6f, "sun");
    float len = sqrtf(dir[0] * dir[0] + dir[1] * dir[1] + dir[2] * dir[2]);
    if (len < 1e-6f) return luaL_error(L, "sun: 'direction' must not be zero");
    field_vec3(L, 1, "color", color, ONE, 0, 1, "sun");
    float intensity = field_number(L, 1, "intensity", 3, 0, 1000, "sun");
    for (int i = 0; i < 3; i++) f->sun_dir[i] = dir[i] / len;
    linear_times(f->sun_color, color, intensity);
    return 0;
}

/* fk.gfx.sun2{direction, color, intensity}: a second star's light (binaries; no shadows); fk.gfx.sun2(nil): none. */
static int l_sun2(lua_State *L) {
    fk_frame *f = fk_frame_get();
    if (lua_isnoneornil(L, 1)) {
        memset(f->sun2_color, 0, sizeof f->sun2_color);
        return 0;
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    float dir[3], color[3];
    static const float UP[3] = {0, 1, 0};
    field_vec3(L, 1, "direction", dir, UP, -1e6f, 1e6f, "sun2");
    float len = sqrtf(dir[0] * dir[0] + dir[1] * dir[1] + dir[2] * dir[2]);
    if (len < 1e-6f) return luaL_error(L, "sun2: 'direction' must not be zero");
    field_vec3(L, 1, "color", color, ONE, 0, 1, "sun2");
    float intensity = field_number(L, 1, "intensity", 3, 0, 1000, "sun2");
    for (int i = 0; i < 3; i++) f->sun2_dir[i] = dir[i] / len;
    linear_times(f->sun2_color, color, intensity);
    return 0;
}

static int l_ambient(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    fk_frame *f = fk_frame_get();
    const float sky_default[3] = {0.5f, 0.6f, 0.75f}, ground_default[3] = {0.3f, 0.28f, 0.25f};
    float sky[3], ground[3];
    field_vec3(L, 1, "sky", sky, sky_default, 0, 1, "ambient");
    field_vec3(L, 1, "ground", ground, ground_default, 0, 1, "ambient");
    float intensity = field_number(L, 1, "intensity", 1, 0, 1000, "ambient");
    linear_times(f->sky, sky, intensity);
    linear_times(f->ground, ground, intensity);
    return 0;
}

static int l_light(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    fk_point_light light;
    float color[3];
    field_world(L, 1, "position", light.position, ZERO, "light");
    field_vec3(L, 1, "color", color, ONE, 0, 1, "light");
    float intensity = field_number(L, 1, "intensity", 10, 0, 1e6f, "light");
    light.radius = field_number(L, 1, "radius", 10, 0.01f, 1e6f, "light");
    linear_times(light.color, color, intensity);
    fk_frame_light(&light);
    return 0;
}

static int l_clear(lua_State *L) {
    float c[3] = {(float)luaL_checknumber(L, 1), (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3)};
    linear_times(fk_frame_get()->background, c, 1);
    return 0;
}

static int l_grade(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    fk_frame *f = fk_frame_get();
    f->exposure = field_number(L, 1, "exposure", 0, -10, 10, "grade");
    f->contrast = field_number(L, 1, "contrast", 1, 0, 4, "grade");
    f->saturation = field_number(L, 1, "saturation", 1, 0, 4, "grade");
    field_vec3(L, 1, "tint", f->tint, ONE, 0, 4, "grade");
    return 0;
}

/* An optional colour argument {r, g, b[, a]} (sRGB, 0..1); default opaque white. */
static void color_arg(lua_State *L, int arg, float out[4], const char *what) {
    out[0] = out[1] = out[2] = out[3] = 1.0f;
    if (lua_isnoneornil(L, arg)) return;
    luaL_checktype(L, arg, LUA_TTABLE);
    lua_Integer n = luaL_len(L, arg);
    if (n != 3 && n != 4) luaL_error(L, "%s: the colour must have 3 or 4 numbers", what);
    for (int i = 0; i < n; i++) {
        out[i] = number_at(L, arg, i + 1, "colour");
        if (out[i] < 0 || out[i] > 1) luaL_error(L, "%s: colour values must be from 0 to 1", what);
    }
}

static int l_text(lua_State *L) {
    float x = (float)luaL_checknumber(L, 1), y = (float)luaL_checknumber(L, 2), color[4];
    const char *text = luaL_checkstring(L, 3);
    color_arg(L, 4, color, "text");
    fk_frame_text(floorf(x), floorf(y), text, color); /* whole pixels keep the font crisp */
    return 0;
}

static int l_rect(lua_State *L) {
    float r[4], color[4];
    for (int i = 0; i < 4; i++) r[i] = floorf((float)luaL_checknumber(L, i + 1));
    color_arg(L, 5, color, "rect");
    fk_frame_rect(r[0], r[1], r[2], r[3], color);
    return 0;
}

/* fk.gfx.palette({{r, g, b}, ...}) quantises the image to these sRGB colours; fk.gfx.palette(nil) switches it off. */
static int l_palette(lua_State *L) {
    fk_frame *f = fk_frame_get();
    if (lua_isnoneornil(L, 1)) {
        f->palette_size = 0;
        return 0;
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_Integer n = luaL_len(L, 1);
    if (n < 1 || n > FK_MAX_PALETTE) return luaL_error(L, "palette: give 1 to %d colours", FK_MAX_PALETTE);
    float colors[FK_MAX_PALETTE][3];
    for (lua_Integer i = 0; i < n; i++) {
        lua_rawgeti(L, 1, i + 1);
        float c[4];
        color_arg(L, lua_gettop(L), c, "palette");
        memcpy(colors[i], c, sizeof colors[i]);
        lua_pop(L, 1);
    }
    memcpy(f->palette, colors, sizeof colors);
    f->palette_size = (int)n;
    return 0;
}

static int l_device(lua_State *L) {
    lua_createtable(L, 0, 3);
    lua_pushstring(L, rendering ? fk_gfx_renderer() : "none");
    lua_setfield(L, -2, "renderer");
    lua_pushboolean(L, fk_platform_web());
    lua_setfield(L, -2, "web");
    lua_pushboolean(L, fk_platform_phone());
    lua_setfield(L, -2, "phone");
    return 1;
}

static int int_field(lua_State *L, const char *name, int def) {
    lua_getfield(L, 1, name);
    int ok = 1;
    lua_Integer v = lua_isnil(L, -1) ? def : lua_tointegerx(L, -1, &ok);
    lua_pop(L, 1);
    if (!ok) luaL_error(L, "configure: '%s' must be an integer", name);
    return (int)v;
}

static bool bool_field(lua_State *L, const char *name, bool def) {
    int type = lua_getfield(L, 1, name);
    bool v = type == LUA_TNIL ? def : lua_toboolean(L, -1);
    lua_pop(L, 1);
    if (type != LUA_TNIL && type != LUA_TBOOLEAN) luaL_error(L, "configure: '%s' must be true or false", name);
    return v;
}

static int l_configure(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    fk_gfx_settings *current = fk_gfx_settings_current(), s = *current;
    s.width = int_field(L, "width", s.width);
    s.height = int_field(L, "height", s.height);
    s.supersample = int_field(L, "supersample", s.supersample);
    s.shadow_cascades = int_field(L, "shadow_cascades", s.shadow_cascades);
    s.shadow_size = int_field(L, "shadow_size", s.shadow_size);
    s.ao_samples = int_field(L, "ao_samples", s.ao_samples);
    s.max_lights = int_field(L, "max_lights", s.max_lights);
    s.max_particles = int_field(L, "max_particles", s.max_particles);
    s.bloom = bool_field(L, "bloom", s.bloom);
    s.hdr = bool_field(L, "hdr", s.hdr);
    s.dither = bool_field(L, "dither", s.dither);
    s.taa = bool_field(L, "taa", s.taa);
    s.fill = bool_field(L, "fill", s.fill);
    s.clouds = bool_field(L, "clouds", s.clouds);
    const char *bad = fk_gfx_settings_check(&s);
    if (bad) return luaL_error(L, "configure: '%s' is out of range", bad);
    *current = s;
    fk_particles_budget(s.max_particles);
    if (!rendering || !s.fill) fk_gfx_set_image_size(s.width, s.height); /* with a window and fill, the pipeline sizes the image */
    if (rendering && !fk_gfx_configure()) return luaL_error(L, "configure: the renderer could not apply these settings");
    return 0;
}

static int l_settings(lua_State *L) {
    const fk_gfx_settings *s = fk_gfx_settings_current();
    lua_createtable(L, 0, 10);
    const struct {
        const char *name;
        int value;
    } ints[] = {{"width", s->width},           {"height", s->height},           {"supersample", s->supersample},
                {"shadow_cascades", s->shadow_cascades}, {"shadow_size", s->shadow_size}, {"ao_samples", s->ao_samples},
                {"max_lights", s->max_lights}, {"max_particles", s->max_particles}};
    for (size_t i = 0; i < sizeof ints / sizeof *ints; i++) {
        lua_pushinteger(L, ints[i].value);
        lua_setfield(L, -2, ints[i].name);
    }
    lua_pushboolean(L, s->bloom);
    lua_setfield(L, -2, "bloom");
    lua_pushboolean(L, s->hdr);
    lua_setfield(L, -2, "hdr");
    lua_pushboolean(L, s->dither);
    lua_setfield(L, -2, "dither");
    lua_pushboolean(L, s->taa);
    lua_setfield(L, -2, "taa");
    lua_pushboolean(L, s->fill);
    lua_setfield(L, -2, "fill");
    lua_pushboolean(L, s->clouds);
    lua_setfield(L, -2, "clouds");
    return 1;
}

static int l_size(lua_State *L) {
    int w, h;
    fk_gfx_image_size(&w, &h);
    lua_pushinteger(L, w);
    lua_pushinteger(L, h);
    return 2;
}

/* fk.gfx.emit{ position, count, ... }: a burst of presentation particles (see the effects spec). */
static int l_emit(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    static const float UP[3] = {0, 1, 0}, WHITE[4] = {1, 1, 1, 1};
    fk_emitter e;
    memset(&e, 0, sizeof e);
    e.count = (int)field_number(L, 1, "count", 1, 0, 4096, "emit");
    field_world(L, 1, "position", e.position, ZERO, "emit");
    e.radius = field_number(L, 1, "radius", 0, 0, 1000, "emit");
    field_vec3(L, 1, "direction", e.direction, UP, -1, 1, "emit");
    e.spread = field_number(L, 1, "spread", 3.1415927f, 0, 3.1415927f, "emit");
    lua_getfield(L, 1, "ring");
    e.ring = lua_toboolean(L, -1);
    lua_getfield(L, 1, "glow");
    e.glow = lua_toboolean(L, -1);
    lua_pop(L, 2);
    e.speed_min = field_number(L, 1, "speed_min", 0, 0, 1000, "emit");
    e.speed_max = field_number(L, 1, "speed_max", e.speed_min, e.speed_min, 1000, "emit");
    e.life_min = field_number(L, 1, "life_min", 1, 0.01f, 60, "emit");
    e.life_max = field_number(L, 1, "life_max", e.life_min, e.life_min, 60, "emit");
    e.size = field_number(L, 1, "size", 0.2f, 0, 100, "emit");
    e.size_end = field_number(L, 1, "size_end", e.size, 0, 100, "emit");
    e.gravity = field_number(L, 1, "gravity", 0, -100, 100, "emit");
    e.drag = field_number(L, 1, "drag", 0, 0, 100, "emit");
    e.stretch = field_number(L, 1, "stretch", 0, 0, 1, "emit");
    float color[3], color_end[3], intensity = field_number(L, 1, "intensity", 1, 0, 1000, "emit");
    field_vec3(L, 1, "color", color, WHITE, 0, 1, "emit");
    field_vec3(L, 1, "color_end", color_end, color, 0, 1, "emit");
    linear_times(e.color, color, intensity);
    linear_times(e.color_end, color_end, intensity);
    e.color[3] = field_number(L, 1, "alpha", 1, 0, 1, "emit");
    e.color_end[3] = field_number(L, 1, "alpha_end", 0, 0, 1, "emit");
    fk_particles_emit(&e);
    return 0;
}

/* fk.gfx.particles(dt): moves the particles on by dt seconds (0 holds them, for hit-pause); returns how many live. */
static int l_particles(lua_State *L) {
    lua_Number dt = luaL_checknumber(L, 1);
    luaL_argcheck(L, dt >= 0 && dt <= 1, 1, "dt must be from 0 to 1 second");
    fk_particles_update((float)dt);
    lua_pushinteger(L, fk_particles_count());
    return 1;
}

void fk_lua_gfx_open(lua_State *L, bool render) {
    static const luaL_Reg gfx[] = {{"mesh", l_mesh},       {"draw", l_draw},         {"overlay", l_overlay},
                                   {"camera", l_camera},   {"sun", l_sun},           {"ambient", l_ambient},
                                   {"light", l_light},     {"clear", l_clear},       {"grade", l_grade},
                                   {"configure", l_configure}, {"settings", l_settings}, {"size", l_size},
                                   {"text", l_text},       {"rect", l_rect},         {"origin", l_origin},         {"palette", l_palette},
                                   {"device", l_device},   {"emit", l_emit},         {"particles", l_particles},
                                   {"slices", l_slices},   {"starfield", l_starfield}, {"sky", l_sky}, {"stats", l_stats}, {"atmosphere", l_atmosphere}, {"sun2", l_sun2},
                                   {"instances", l_instances}, {"wind", l_wind}, {"water", l_water},
                                   {NULL, NULL}};
    rendering = render;
    static const luaL_Reg sky_methods[] = {{"ready", l_sky_ready}, {"stars", l_sky_stars}, {NULL, NULL}};
    luaL_newmetatable(L, "fk.sky_map");
    lua_pushcfunction(L, l_sky_gc);
    lua_setfield(L, -2, "__gc");
    luaL_newlib(L, sky_methods);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    luaL_newmetatable(L, "fk.mesh");
    lua_pushcfunction(L, l_mesh_gc);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);
    luaL_newmetatable(L, "fk.instances");
    lua_pushcfunction(L, l_instances_gc);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);
    fk_script_frame_begin(L);
    luaL_newlib(L, gfx);
    fk_lua_assets_open(L, render);
}
