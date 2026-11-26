/* fk.gfx.texture and fk.gfx.model: files from data/, cached by path, reloaded in place when they change
   (hot reload polls on desktop debug builds). Without rendering they are decoded and checked only. */
#include <stdio.h>
#include <string.h>

#include "assets/image.h"
#include "assets/model.h"
#include "assets/vfs.h"
#include "assets/watch.h"
#include "core/mat4.h"
#include "gfx/frame.h"
#include "lauxlib.h"
#include "platform/platform.h"
#include "script/script.h"

static bool rendering;

typedef struct {
    fk_texture tex;
    char rel[256];
} lua_texture;

typedef struct {
    fk_model model;
    char rel[256];
} lua_model;

/* Paths are relative to data/ and may not leave it. */
static const char *checked_path(lua_State *L, int arg, const char *what) {
    const char *rel = luaL_checkstring(L, arg);
    size_t n = strlen(rel);
    bool ok = n > 0 && n < 256 && rel[0] != '/' && strspn(rel, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./") == n &&
              strstr(rel, "..") == NULL;
    if (!ok) luaL_error(L, "%s: '%s' is not a path inside data/ (letters, digits, '_', '-', '.', '/')", what, rel);
    return rel;
}

/* Pushes the cached object for key, or nothing and returns false. */
static bool cached(lua_State *L, const char *key) {
    lua_getfield(L, LUA_REGISTRYINDEX, "fk.assets");
    if (lua_getfield(L, -1, key) != LUA_TNIL) {
        lua_remove(L, -2);
        return true;
    }
    lua_pop(L, 2);
    return false;
}

static void cache(lua_State *L, const char *key) { /* the object is on top */
    lua_getfield(L, LUA_REGISTRYINDEX, "fk.assets");
    lua_pushvalue(L, -2);
    lua_setfield(L, -2, key);
    lua_pop(L, 1);
}

/* Decodes data/<rel> into tex (uploading when rendering). Returns NULL or the reason it failed. */
static const char *load_texture(fk_texture *tex, const char *rel) {
    size_t size;
    void *file = fk_vfs_read(rel, &size);
    if (!file) return "cannot find the file";
    int w, h;
    const char *why = NULL;
    uint8_t *rgba = fk_image_decode(file, size, &w, &h, &why);
    fk_platform_free(file);
    if (!rgba) return why;
    if (rendering) fk_gfx_texture_upload(tex, rgba, w, h, true);
    else tex->width = w, tex->height = h;
    fk_image_free(rgba);
    return NULL;
}

static void reload_texture(void *user) {
    lua_texture *t = user;
    const char *why = load_texture(&t->tex, t->rel);
    if (why) fk_log("hot reload: %s: %s", t->rel, why);
    else fk_log("hot reload: %s", t->rel);
}

static void reload_model(void *user) {
    lua_model *m = user;
    fk_model next;
    char error[256];
    if (!fk_model_load(&next, m->rel, error, sizeof error)) {
        fk_log("hot reload: %s", error);
        return;
    }
    if (rendering) fk_model_upload(&next);
    fk_model_free(&m->model);
    m->model = next;
    fk_log("hot reload: %s", m->rel);
}

static void watch(const char *rel, fk_watch_fn fn, void *user) {
    char path[1024];
    fk_watch_add(fk_vfs_path(rel, path, sizeof path), fn, user);
}

static int l_texture(lua_State *L) {
    const char *rel = checked_path(L, 1, "texture");
    char key[300];
    snprintf(key, sizeof key, "texture:%s", rel);
    if (cached(L, key)) return 1;
    lua_texture *t = lua_newuserdatauv(L, sizeof *t, 0);
    memset(t, 0, sizeof *t);
    luaL_setmetatable(L, "fk.texture");
    snprintf(t->rel, sizeof t->rel, "%s", rel);
    const char *why = load_texture(&t->tex, rel);
    if (why) return luaL_error(L, "texture: %s: %s", rel, why);
    watch(rel, reload_texture, t);
    cache(L, key);
    return 1;
}

static int l_texture_gc(lua_State *L) {
    lua_texture *t = luaL_checkudata(L, 1, "fk.texture");
    fk_watch_remove(t);
    if (t->tex.id) fk_gfx_texture_destroy(&t->tex);
    return 0;
}

static int l_texture_size(lua_State *L) {
    lua_texture *t = luaL_checkudata(L, 1, "fk.texture");
    lua_pushinteger(L, t->tex.width);
    lua_pushinteger(L, t->tex.height);
    return 2;
}

static int l_model(lua_State *L) {
    const char *rel = checked_path(L, 1, "model");
    char key[300];
    snprintf(key, sizeof key, "model:%s", rel);
    if (cached(L, key)) return 1;
    lua_model *m = lua_newuserdatauv(L, sizeof *m, 0);
    memset(m, 0, sizeof *m);
    luaL_setmetatable(L, "fk.model");
    snprintf(m->rel, sizeof m->rel, "%s", rel);
    char error[256];
    if (!fk_model_load(&m->model, rel, error, sizeof error)) return luaL_error(L, "model: %s", error);
    if (rendering) fk_model_upload(&m->model);
    watch(rel, reload_model, m);
    cache(L, key);
    return 1;
}

static int l_model_gc(lua_State *L) {
    lua_model *m = luaL_checkudata(L, 1, "fk.model");
    fk_watch_remove(m);
    fk_model_free(&m->model);
    return 0;
}

/* model:clips() -> { { name = "walk", duration = 1.2 }, ... } in file order */
static int l_model_clips(lua_State *L) {
    lua_model *m = luaL_checkudata(L, 1, "fk.model");
    lua_createtable(L, m->model.clip_count, 0);
    for (int i = 0; i < m->model.clip_count; i++) {
        lua_createtable(L, 0, 2);
        lua_pushstring(L, m->model.clips[i].name);
        lua_setfield(L, -2, "name");
        lua_pushnumber(L, m->model.clips[i].duration);
        lua_setfield(L, -2, "duration");
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

/* model:nodes() -> { "name", ... } in file order */
static int l_model_nodes(lua_State *L) {
    lua_model *m = luaL_checkudata(L, 1, "fk.model");
    lua_createtable(L, m->model.node_count, 0);
    for (int i = 0; i < m->model.node_count; i++) {
        lua_pushstring(L, m->model.nodes[i].name);
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

const fk_texture *fk_lua_texture_arg(lua_State *L, int arg) {
    lua_texture *t = luaL_testudata(L, arg, "fk.texture");
    return t ? &t->tex : NULL;
}

fk_model *fk_lua_model_arg(lua_State *L, int arg) {
    lua_model *m = luaL_testudata(L, arg, "fk.model");
    return m ? &m->model : NULL;
}

/* Records a draw per primitive of the model at its nodes' rest pose (or the given node matrices). */
void fk_lua_draw_model(const fk_model *m, const float matrix[16], const float *node_matrices) {
    static const fk_mesh empty; /* without rendering there are no GPU meshes */
    for (int n = 0; n < m->node_count; n++) {
        const fk_node *node = &m->nodes[n];
        if (!node->primitive_count) continue;
        float world[16];
        fk_mat4_mul(world, matrix, node_matrices ? &node_matrices[n * 16] : node->global);
        for (int i = node->first_primitive; i < node->first_primitive + node->primitive_count; i++) {
            fk_material mat;
            fk_material_default(&mat);
            int mi = m->primitives[i].material;
            if (mi >= 0) {
                const fk_model_material *src = &m->materials[mi];
                memcpy(mat.base, src->base, sizeof mat.base);
                mat.roughness = src->roughness;
                mat.metalness = src->metalness;
                memcpy(mat.emission, src->emission, sizeof mat.emission);
                mat.normal_scale = src->normal_scale;
                if (m->textures) {
                    mat.base_tex = src->base_tex >= 0 ? &m->textures[src->base_tex] : NULL;
                    mat.metal_rough_tex = src->metal_rough_tex >= 0 ? &m->textures[src->metal_rough_tex] : NULL;
                    mat.normal_tex = src->normal_tex >= 0 ? &m->textures[src->normal_tex] : NULL;
                    mat.emission_tex = src->emission_tex >= 0 ? &m->textures[src->emission_tex] : NULL;
                }
            }
            fk_frame_draw(m->meshes ? &m->meshes[i] : &empty, world, &mat);
        }
    }
}

void fk_lua_assets_open(lua_State *L, bool render) {
    rendering = render;
    lua_newtable(L);
    lua_createtable(L, 0, 1);
    lua_pushliteral(L, "v");
    lua_setfield(L, -2, "__mode");
    lua_setmetatable(L, -2);
    lua_setfield(L, LUA_REGISTRYINDEX, "fk.assets");
    static const luaL_Reg texture_methods[] = {{"size", l_texture_size}, {NULL, NULL}};
    static const luaL_Reg model_methods[] = {{"clips", l_model_clips}, {"nodes", l_model_nodes}, {NULL, NULL}};
    luaL_newmetatable(L, "fk.texture");
    lua_pushcfunction(L, l_texture_gc);
    lua_setfield(L, -2, "__gc");
    luaL_newlib(L, texture_methods);
    lua_setfield(L, -2, "__index");
    luaL_newmetatable(L, "fk.model");
    lua_pushcfunction(L, l_model_gc);
    lua_setfield(L, -2, "__gc");
    luaL_newlib(L, model_methods);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 2);
    /* the fk.gfx table is on top */
    lua_pushcfunction(L, l_texture);
    lua_setfield(L, -2, "texture");
    lua_pushcfunction(L, l_model);
    lua_setfield(L, -2, "model");
}
