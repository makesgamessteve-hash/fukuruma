/* fk.galaxy: the galaxy's density and the stars of its sectors, now or in the background (core/jobs.h). */
#include <stdlib.h>

#include "core/jobs.h"
#include "gen/galaxy.h"
#include "lauxlib.h"
#include "script/script.h"

static const char *const KINDS[FK_STAR_KINDS] = {"star", "white_dwarf", "neutron_star", "black_hole", "brown_dwarf", "giant", "rogue_planet"};

static const char *spectral(const fk_star *s) {
    if (s->kind != FK_STAR) return "";
    double t = s->temperature;
    return t > 30000 ? "O" : t > 10000 ? "B" : t > 7500 ? "A" : t > 6000 ? "F" : t > 5200 ? "G" : t > 3700 ? "K" : "M";
}

static void push_vec(lua_State *L, const double *v, int n) {
    lua_createtable(L, n, 0);
    for (int i = 0; i < n; i++) {
        lua_pushnumber(L, v[i]);
        lua_rawseti(L, -2, i + 1);
    }
}

static void push_star(lua_State *L, const fk_star *s) {
    lua_createtable(L, 0, 10);
    lua_pushinteger(L, (lua_Integer)s->seed);
    lua_setfield(L, -2, "seed");
    push_vec(L, s->pos, 3);
    lua_setfield(L, -2, "position");
    lua_pushstring(L, KINDS[s->kind]);
    lua_setfield(L, -2, "kind");
    lua_pushstring(L, spectral(s));
    lua_setfield(L, -2, "class");
    const double nums[4] = {s->mass, s->radius, s->luminosity, s->temperature};
    static const char *const names[4] = {"mass", "radius", "luminosity", "temperature"};
    for (int i = 0; i < 4; i++) {
        lua_pushnumber(L, nums[i]);
        lua_setfield(L, -2, names[i]);
    }
    const double c[3] = {s->color[0], s->color[1], s->color[2]};
    push_vec(L, c, 3);
    lua_setfield(L, -2, "color");
}

static void push_stars(lua_State *L, const fk_star *stars, int n) {
    lua_createtable(L, n, 0);
    for (int i = 0; i < n; i++) {
        push_star(L, &stars[i]);
        lua_rawseti(L, -2, i + 1);
    }
}

static uint64_t seed_arg(lua_State *L, int arg) { return (uint64_t)luaL_checkinteger(L, arg); }

/* fk.galaxy.sector(seed, sx, sy, sz) -> the sector's stars */
static int l_sector(lua_State *L) {
    fk_star *stars = malloc(FK_SECTOR_MAX_STARS * sizeof *stars);
    if (!stars) return luaL_error(L, "out of memory");
    int n = fk_galaxy_sector(seed_arg(L, 1), luaL_checkinteger(L, 2), luaL_checkinteger(L, 3), luaL_checkinteger(L, 4), stars);
    push_stars(L, stars, n);
    free(stars);
    return 1;
}

typedef struct {
    uint64_t seed;
    int64_t s[3];
    fk_star *stars;
    int n;
    uint32_t job;
} request;

static void generate(void *data) {
    request *r = data;
    r->n = fk_galaxy_sector(r->seed, r->s[0], r->s[1], r->s[2], r->stars);
}

/* fk.galaxy.request(seed, sx, sy, sz) -> a request generated in the background: request:ready(), request:stars() */
static int l_request(lua_State *L) {
    request *r = lua_newuserdatauv(L, sizeof *r, 0);
    r->stars = NULL, r->job = 0;
    luaL_setmetatable(L, "fk.sector_request");
    r->seed = seed_arg(L, 1);
    for (int i = 0; i < 3; i++) r->s[i] = luaL_checkinteger(L, i + 2);
    r->stars = malloc(FK_SECTOR_MAX_STARS * sizeof *r->stars);
    if (!r->stars) return luaL_error(L, "out of memory");
    r->job = fk_jobs_submit(generate, r);
    return 1;
}

static int l_ready(lua_State *L) {
    request *r = luaL_checkudata(L, 1, "fk.sector_request");
    lua_pushboolean(L, fk_jobs_done(r->job));
    return 1;
}

static int l_stars(lua_State *L) { /* waits if it is not ready yet */
    request *r = luaL_checkudata(L, 1, "fk.sector_request");
    fk_jobs_wait(r->job);
    push_stars(L, r->stars, r->n);
    return 1;
}

static int l_request_gc(lua_State *L) {
    request *r = luaL_checkudata(L, 1, "fk.sector_request");
    if (r->job) fk_jobs_wait(r->job); /* the job writes into stars */
    free(r->stars);
    r->stars = NULL, r->job = 0;
    return 0;
}

static int l_density(lua_State *L) {
    double p[3] = {luaL_checknumber(L, 1), luaL_checknumber(L, 2), luaL_checknumber(L, 3)};
    lua_pushnumber(L, fk_galaxy_density(p));
    return 1;
}

/* fk.galaxy.physics(kind, mass, seed) -> {radius, luminosity, temperature, color} for companions and the like */
static int l_physics(lua_State *L) {
    fk_star s = {0};
    s.kind = luaL_checkoption(L, 1, NULL, KINDS);
    s.mass = luaL_checknumber(L, 2);
    luaL_argcheck(L, s.mass > 0, 2, "the mass must be above 0");
    s.seed = (uint64_t)luaL_optinteger(L, 3, 0);
    fk_star_physics(&s);
    push_star(L, &s);
    return 1;
}

void fk_lua_galaxy_open(lua_State *L) {
    static const luaL_Reg methods[] = {{"ready", l_ready}, {"stars", l_stars}, {NULL, NULL}};
    luaL_newmetatable(L, "fk.sector_request");
    lua_pushcfunction(L, l_request_gc);
    lua_setfield(L, -2, "__gc");
    luaL_newlib(L, methods);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    static const luaL_Reg fns[] = {{"sector", l_sector},   {"request", l_request}, {"density", l_density},
                                   {"physics", l_physics}, {NULL, NULL}};
    luaL_newlib(L, fns);
    lua_pushnumber(L, FK_SECTOR_LY);
    lua_setfield(L, -2, "SECTOR");
    push_vec(L, FK_GALAXY_HOME, 3);
    lua_setfield(L, -2, "HOME");
}
