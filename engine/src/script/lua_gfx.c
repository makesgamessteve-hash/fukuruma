/* fk.gfx: meshes, camera, lights, materials, overlay and graphics settings for scripts. Everything is
   validated (mods are scripts too); without rendering, calls only validate and record. */
#include <math.h>
#include <string.h>

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

void fk_script_frame_begin(lua_State *L) {
    lua_newtable(L);
    lua_setfield(L, LUA_REGISTRYINDEX, "fk.frame_meshes");
    fk_frame_begin();
}

static int l_mesh(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_settop(L, 1);
    lua_Integer np = field_table(L, "positions"), nc = field_table(L, "colors"), ni = field_table(L, "indices");
    int nt = lua_getfield(L, 1, "normals");
    if (np == 0 || np % 3) return luaL_error(L, "mesh: positions must hold x, y, z for at least one vertex");
    if (nc != np) return luaL_error(L, "mesh: colors must hold r, g, b for every vertex");
    if (nt != LUA_TNIL && (nt != LUA_TTABLE || luaL_len(L, 5) != np)) return luaL_error(L, "mesh: normals must hold x, y, z for every vertex");
    if (ni == 0 || ni % 3) return luaL_error(L, "mesh: indices must describe whole triangles");
    lua_Integer nv = np / 3;
    if (nv > FK_MAX_VERTICES || ni > 3 * FK_MAX_VERTICES) return luaL_error(L, "mesh: too large");
    /* Scratch buffers are userdata, so an error in the middle does not leak them. */
    float *v = lua_newuserdatauv(L, (size_t)nv * 9 * sizeof(float), 0);
    uint32_t *idx = lua_newuserdatauv(L, (size_t)ni * sizeof(uint32_t), 0);
    for (lua_Integer i = 0; i < nv; i++)
        for (int k = 0; k < 3; k++) {
            v[i * 9 + k] = number_at(L, 2, i * 3 + k + 1, "positions");
            v[i * 9 + 3 + k] = number_at(L, 3, i * 3 + k + 1, "colors");
            if (nt == LUA_TTABLE) v[i * 9 + 6 + k] = number_at(L, 5, i * 3 + k + 1, "normals");
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

static int l_mesh_gc(lua_State *L) {
    fk_mesh *m = luaL_checkudata(L, 1, "fk.mesh");
    if (m->vao) fk_gfx_mesh_destroy(m);
    return 0;
}

static const float ZERO[3] = {0, 0, 0}, ONE[3] = {1, 1, 1};

static int l_draw(lua_State *L) {
    fk_mesh *m = luaL_checkudata(L, 1, "fk.mesh");
    float model[16];
    matrix_arg(L, 2, model, "draw");
    fk_material mat = {0.6f, 0.0f, {0, 0, 0}};
    if (!lua_isnoneornil(L, 3)) {
        luaL_checktype(L, 3, LUA_TTABLE);
        mat.roughness = field_number(L, 3, "roughness", 0.6f, 0, 1, "draw");
        mat.metalness = field_number(L, 3, "metalness", 0, 0, 1, "draw");
        field_vec3(L, 3, "emission", mat.emission, ZERO, 0, 1000, "draw");
    }
    keep_alive(L, 1);
    fk_frame_draw(m, model, &mat);
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
    field_vec3(L, 1, "position", light.position, ZERO, -1e9f, 1e9f, "light");
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
    s.bloom = bool_field(L, "bloom", s.bloom);
    s.hdr = bool_field(L, "hdr", s.hdr);
    s.dither = bool_field(L, "dither", s.dither);
    s.taa = bool_field(L, "taa", s.taa);
    s.fill = bool_field(L, "fill", s.fill);
    const char *bad = fk_gfx_settings_check(&s);
    if (bad) return luaL_error(L, "configure: '%s' is out of range", bad);
    *current = s;
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
                {"max_lights", s->max_lights}};
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
    return 1;
}

static int l_size(lua_State *L) {
    int w, h;
    fk_gfx_image_size(&w, &h);
    lua_pushinteger(L, w);
    lua_pushinteger(L, h);
    return 2;
}

void fk_lua_gfx_open(lua_State *L, bool render) {
    static const luaL_Reg gfx[] = {{"mesh", l_mesh},       {"draw", l_draw},         {"overlay", l_overlay},
                                   {"camera", l_camera},   {"sun", l_sun},           {"ambient", l_ambient},
                                   {"light", l_light},     {"clear", l_clear},       {"grade", l_grade},
                                   {"configure", l_configure}, {"settings", l_settings}, {"size", l_size},
                                   {"text", l_text},       {"rect", l_rect},         {"palette", l_palette},
                                   {"device", l_device},   {NULL, NULL}};
    rendering = render;
    luaL_newmetatable(L, "fk.mesh");
    lua_pushcfunction(L, l_mesh_gc);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);
    fk_script_frame_begin(L);
    luaL_newlib(L, gfx);
}
