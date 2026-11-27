/* fk.planet: planet surfaces for scripts (gen/planet.h). fk.planet.new(def) describes a planet; planet:chunk(face,
   level, x, y) builds a chunk's mesh in the background; request:mesh() gives the fk.mesh, its centre (metres, planet
   axes) and bounding radius. */
#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "core/jobs.h"
#include "gen/planet.h"
#include "lauxlib.h"
#include "script/script.h"

static const char *const PALETTE[FK_PAL_COUNT] = {"deep", "shallow", "beach", "low",   "mid",    "high",
                                                  "peak", "ice",     "grass", "forest", "desert", "tundra"};

static double field(lua_State *L, int t, const char *name, double def) {
    lua_getfield(L, t, name);
    double v = lua_isnil(L, -1) ? def : luaL_checknumber(L, -1);
    lua_pop(L, 1);
    return v;
}

static bool flag(lua_State *L, int t, const char *name) {
    lua_getfield(L, t, name);
    bool v = lua_toboolean(L, -1);
    lua_pop(L, 1);
    return v;
}

/* fk.planet.new{radius, relief, sea_level, ocean, life, bands, temperature, ice_latitude, palette = {name = {r, g, b}},
   height = graph, moisture = graph} */
static int l_new(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    fk_planet *p = lua_newuserdatauv(L, sizeof *p, 0);
    memset(p, 0, sizeof *p);
    luaL_setmetatable(L, "fk.planet_surface");
    p->radius = field(L, 1, "radius", 6.371e6);
    p->relief = field(L, 1, "relief", 8000);
    p->sea_level = field(L, 1, "sea_level", 0);
    p->temperature = field(L, 1, "temperature", 288);
    p->ice_latitude = field(L, 1, "ice_latitude", 0.9);
    p->ocean = flag(L, 1, "ocean"), p->life = flag(L, 1, "life"), p->bands = flag(L, 1, "bands");
    luaL_argcheck(L, p->radius > 0 && p->relief >= 0, 1, "radius must be above 0 and relief at least 0");
    for (int i = 0; i < FK_PAL_COUNT; i++) p->palette[i][0] = p->palette[i][1] = p->palette[i][2] = 0.5f;
    if (lua_getfield(L, 1, "palette") == LUA_TTABLE) {
        for (int i = 0; i < FK_PAL_COUNT; i++) {
            if (lua_getfield(L, -1, PALETTE[i]) == LUA_TTABLE) {
                for (int k = 0; k < 3; k++) {
                    lua_rawgeti(L, -1, k + 1);
                    p->palette[i][k] = (float)luaL_checknumber(L, -1);
                    lua_pop(L, 1);
                }
            }
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
    if (lua_getfield(L, 1, "height") != LUA_TNIL) p->height = *fk_lua_noise_arg(L, lua_gettop(L));
    else if (!p->bands) return luaL_error(L, "planet: 'height' must be a noise graph");
    lua_pop(L, 1);
    if (lua_getfield(L, 1, "moisture") != LUA_TNIL) p->moisture = *fk_lua_noise_arg(L, lua_gettop(L));
    lua_pop(L, 1);
    if (lua_getfield(L, 1, "clouds") != LUA_TNIL) p->clouds = *fk_lua_noise_arg(L, lua_gettop(L));
    lua_pop(L, 1);
    p->cloud_cover = field(L, 1, "cloud_cover", 0);
    return 1;
}

static fk_planet *planet_arg(lua_State *L, int arg) { return luaL_checkudata(L, arg, "fk.planet_surface"); }

static void dir_arg(lua_State *L, int arg, double d[3]) {
    double l = 0;
    for (int i = 0; i < 3; i++) d[i] = luaL_checknumber(L, arg + i), l += d[i] * d[i];
    luaL_argcheck(L, l > 0, arg, "the direction must not be zero");
    l = sqrt(l);
    for (int i = 0; i < 3; i++) d[i] /= l;
}

/* planet:height(x, y, z) -> metres above the radius in that direction */
static int l_height(lua_State *L) {
    double d[3];
    dir_arg(L, 2, d);
    lua_pushnumber(L, fk_planet_height(planet_arg(L, 1), d));
    return 1;
}

/* planet:flatten(x, y, z, radius): levels the site around that direction (call before building chunks) */
static int l_flatten(lua_State *L) {
    double d[3];
    dir_arg(L, 2, d);
    double r = luaL_checknumber(L, 5);
    luaL_argcheck(L, r > 0 && r < 1e6, 5, "the radius must be above 0 and below 1000 km");
    fk_planet_flatten(planet_arg(L, 1), d, r);
    return 0;
}

static void unit_field(lua_State *L, int t, const char *name, double d[3]) {
    if (lua_getfield(L, t, name) != LUA_TTABLE) luaL_error(L, "grid: '%s' must be a unit vector {x, y, z}", name);
    double l = 0;
    for (int i = 0; i < 3; i++) {
        lua_rawgeti(L, -1, i + 1);
        d[i] = luaL_checknumber(L, -1), l += d[i] * d[i];
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
    if (!(fabs(l - 1) < 1e-6)) luaL_error(L, "grid: '%s' must be a unit vector {x, y, z}", name);
}

/* planet:grid{up, east, north, origin = {x0, z0}, cell, n} -> (n + 1)^2 heights for a terrain (see fk_planet_grid) */
static int l_grid(lua_State *L) {
    fk_planet *p = planet_arg(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    double up[3], east[3], north[3], origin[2] = {0, 0};
    unit_field(L, 2, "up", up);
    unit_field(L, 2, "east", east);
    unit_field(L, 2, "north", north);
    if (lua_getfield(L, 2, "origin") == LUA_TTABLE)
        for (int i = 0; i < 2; i++) {
            lua_rawgeti(L, -1, i + 1);
            origin[i] = luaL_checknumber(L, -1);
            lua_pop(L, 1);
        }
    lua_pop(L, 1);
    double cell = field(L, 2, "cell", 1);
    int n = (int)field(L, 2, "n", 32);
    luaL_argcheck(L, cell > 0 && n >= 1 && n <= 256, 2, "grid: 'cell' must be above 0 and 'n' from 1 to 256");
    int count = (n + 1) * (n + 1);
    float *h = lua_newuserdatauv(L, (size_t)count * sizeof *h, 0);
    fk_planet_grid(p, up, east, north, origin[0], origin[1], cell, n, h);
    lua_createtable(L, count, 0);
    for (int i = 0; i < count; i++) {
        lua_pushnumber(L, h[i]);
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

/* planet:color(x, y, z) -> r, g, b (sRGB) */
static int l_color(lua_State *L) {
    fk_planet *p = planet_arg(L, 1);
    double d[3];
    dir_arg(L, 2, d);
    float rgb[3];
    fk_planet_color(p, d, fk_planet_height(p, d), rgb);
    for (int i = 0; i < 3; i++) lua_pushnumber(L, rgb[i]);
    return 3;
}

typedef struct {
    const fk_planet *planet;
    int face, level, x, y;
    fk_vertex *vertices;
    uint32_t *indices;
    double centre[3], bound;
    uint32_t job;
} chunk;

static void build(void *data) {
    chunk *c = data;
    c->bound = fk_planet_chunk(c->planet, c->face, c->level, c->x, c->y, c->vertices, c->indices, c->centre);
}

/* planet:chunk(face (0..5), level (0..24), x, y) -> a request built in the background */
static int l_chunk(lua_State *L) {
    fk_planet *p = planet_arg(L, 1);
    int face = (int)luaL_checkinteger(L, 2), level = (int)luaL_checkinteger(L, 3);
    int x = (int)luaL_checkinteger(L, 4), y = (int)luaL_checkinteger(L, 5);
    luaL_argcheck(L, face >= 0 && face < 6, 2, "the face must be from 0 to 5");
    luaL_argcheck(L, level >= 0 && level <= 24, 3, "the level must be from 0 to 24");
    luaL_argcheck(L, x >= 0 && y >= 0 && x < (1 << level) && y < (1 << level), 4, "x and y must be inside the face at this level");
    chunk *c = lua_newuserdatauv(L, sizeof *c, 2);
    memset(c, 0, sizeof *c);
    luaL_setmetatable(L, "fk.planet_chunk");
    lua_pushvalue(L, 1);
    lua_setiuservalue(L, -2, 1); /* the planet stays alive while its chunk is built */
    c->planet = p, c->face = face, c->level = level, c->x = x, c->y = y;
    c->vertices = malloc((size_t)FK_CHUNK_VERTICES * sizeof *c->vertices);
    c->indices = malloc((size_t)FK_CHUNK_INDICES * sizeof *c->indices);
    if (!c->vertices || !c->indices) return luaL_error(L, "out of memory");
    c->job = fk_jobs_submit(build, c);
    return 1;
}

static int l_ready(lua_State *L) {
    chunk *c = luaL_checkudata(L, 1, "fk.planet_chunk");
    lua_pushboolean(L, !c->vertices || fk_jobs_done(c->job));
    return 1;
}

/* request:mesh() -> mesh, centre {x, y, z}, bound (waits if needed; the same mesh every time) */
static int l_mesh(lua_State *L) {
    chunk *c = luaL_checkudata(L, 1, "fk.planet_chunk");
    if (c->vertices) {
        fk_jobs_wait(c->job);
        fk_lua_push_mesh(L, c->vertices, FK_CHUNK_VERTICES, c->indices, FK_CHUNK_INDICES);
        lua_setiuservalue(L, 1, 2);
        free(c->vertices), free(c->indices);
        c->vertices = NULL, c->indices = NULL;
    }
    lua_getiuservalue(L, 1, 2);
    lua_createtable(L, 3, 0);
    for (int i = 0; i < 3; i++) {
        lua_pushnumber(L, c->centre[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_pushnumber(L, c->bound);
    return 3;
}

static int l_chunk_gc(lua_State *L) {
    chunk *c = luaL_checkudata(L, 1, "fk.planet_chunk");
    if (c->vertices) fk_jobs_wait(c->job); /* the job writes into the buffers */
    free(c->vertices), free(c->indices);
    c->vertices = NULL, c->indices = NULL;
    return 0;
}

static int l_direction(lua_State *L) { /* fk.planet.direction(face, u, v) -> x, y, z on the unit sphere */
    double d[3];
    int face = (int)luaL_checkinteger(L, 1);
    luaL_argcheck(L, face >= 0 && face < 6, 1, "the face must be from 0 to 5");
    fk_cube_to_sphere(face, luaL_checknumber(L, 2), luaL_checknumber(L, 3), d);
    for (int i = 0; i < 3; i++) lua_pushnumber(L, d[i]);
    return 3;
}

void fk_lua_planet_open(lua_State *L) {
    static const luaL_Reg planet[] = {{"height", l_height}, {"color", l_color}, {"chunk", l_chunk},
                                       {"flatten", l_flatten}, {"grid", l_grid}, {NULL, NULL}};
    static const luaL_Reg request[] = {{"ready", l_ready}, {"mesh", l_mesh}, {NULL, NULL}};
    luaL_newmetatable(L, "fk.planet_surface");
    luaL_newlib(L, planet);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    luaL_newmetatable(L, "fk.planet_chunk");
    lua_pushcfunction(L, l_chunk_gc);
    lua_setfield(L, -2, "__gc");
    luaL_newlib(L, request);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    static const luaL_Reg fns[] = {{"new", l_new}, {"direction", l_direction}, {NULL, NULL}};
    luaL_newlib(L, fns);
    lua_pushinteger(L, FK_CHUNK_GRID);
    lua_setfield(L, -2, "GRID");
}
