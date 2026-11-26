/* fk.audio: sounds, voices, music tracks, buses, the listener and reverb for scripts. Every mixer call holds the
   audio lock. Sounds are presentation: they never change the simulation. */
#include <math.h>
#include <stdio.h>
#include <string.h>

#include "assets/sound.h"
#include "assets/vfs.h"
#include "assets/watch.h"
#include "audio/mixer.h"
#include "core/rng.h"
#include "lauxlib.h"
#include "platform/platform.h"
#include "script/script.h"

typedef struct {
    fk_sound sound;
    char rel[256];
} lua_sound;

static fk_rng rng; /* variations and pitch jitter: presentation's own stream */

static const char *load_sound(fk_sound *out, const char *rel) {
    size_t size;
    void *file = fk_vfs_read(rel, &size);
    if (!file) return "cannot find the file";
    const char *why = NULL;
    bool ok = fk_sound_decode(file, size, out, &why);
    fk_platform_free(file);
    return ok ? NULL : why;
}

static void reload_sound(void *user) {
    lua_sound *s = user;
    fk_sound next;
    const char *why = load_sound(&next, s->rel);
    if (why) {
        fk_log("hot reload: %s: %s", s->rel, why);
        return;
    }
    fk_platform_audio_lock();
    fk_mixer_stop_sound(&s->sound);
    fk_sound_free(&s->sound);
    s->sound = next;
    fk_platform_audio_unlock();
    fk_log("hot reload: %s", s->rel);
}

static bool valid_path(const char *rel) {
    size_t n = strlen(rel);
    return n > 0 && n < 256 && rel[0] != '/' && !strstr(rel, "..") &&
           strspn(rel, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./") == n;
}

/* Pushes the sound at data/<rel> (cached); raises a script error when it cannot be loaded. */
static lua_sound *push_sound(lua_State *L, const char *rel) {
    if (!valid_path(rel)) luaL_error(L, "sound: '%s' is not a path inside data/", rel);
    char key[300], path[1024];
    snprintf(key, sizeof key, "sound:%s", rel);
    lua_getfield(L, LUA_REGISTRYINDEX, "fk.assets");
    if (lua_getfield(L, -1, key) != LUA_TNIL) {
        lua_remove(L, -2);
        return lua_touserdata(L, -1);
    }
    lua_pop(L, 1);
    lua_sound *s = lua_newuserdatauv(L, sizeof *s, 0);
    memset(s, 0, sizeof *s);
    luaL_setmetatable(L, "fk.sound");
    snprintf(s->rel, sizeof s->rel, "%s", rel);
    const char *why = load_sound(&s->sound, rel);
    if (why) luaL_error(L, "sound: %s: %s", rel, why);
    fk_watch_add(fk_vfs_path(rel, path, sizeof path), reload_sound, s);
    lua_pushvalue(L, -1);
    lua_setfield(L, -3, key);
    lua_remove(L, -2);
    return s;
}

static int l_sound(lua_State *L) {
    push_sound(L, luaL_checkstring(L, 1));
    return 1;
}

static int l_sound_gc(lua_State *L) {
    lua_sound *s = luaL_checkudata(L, 1, "fk.sound");
    fk_watch_remove(s);
    fk_platform_audio_lock();
    fk_mixer_stop_sound(&s->sound);
    fk_platform_audio_unlock();
    fk_sound_free(&s->sound);
    return 0;
}

static int l_sound_length(lua_State *L) {
    lua_sound *s = luaL_checkudata(L, 1, "fk.sound");
    lua_pushnumber(L, (lua_Number)s->sound.frames / FK_AUDIO_RATE);
    return 1;
}

static bool exists(const char *rel) {
    char path[1024];
    int64_t mtime;
    uint64_t size;
    return fk_platform_file_info(fk_vfs_path(rel, path, sizeof path), &mtime, &size);
}

/* The variations of a named sound: data/sounds/<name>.ogg, or <name>_1.ogg, <name>_2.ogg, ... (cached list). */
static int push_bank(lua_State *L, const char *name) {
    size_t n = strlen(name);
    if (n == 0 || n > 64 || strspn(name, "abcdefghijklmnopqrstuvwxyz0123456789_") != n)
        luaL_error(L, "play: '%s' is not a sound name (lowercase letters, digits and '_')", name);
    lua_getfield(L, LUA_REGISTRYINDEX, "fk.sound_banks");
    if (lua_getfield(L, -1, name) == LUA_TTABLE) {
        lua_remove(L, -2);
        return (int)luaL_len(L, -1);
    }
    lua_pop(L, 1);
    lua_newtable(L);
    char rel[128];
    int count = 0;
    snprintf(rel, sizeof rel, "sounds/%s.ogg", name);
    if (exists(rel)) {
        push_sound(L, rel);
        lua_rawseti(L, -2, ++count);
    }
    for (int i = 1; !count || i <= 9; i++) {
        snprintf(rel, sizeof rel, "sounds/%s_%d.ogg", name, i);
        if (!exists(rel)) break;
        push_sound(L, rel);
        lua_rawseti(L, -2, ++count);
    }
    if (!count) luaL_error(L, "play: no sound named '%s' (data/sounds/%s.ogg or %s_1.ogg, ...)", name, name, name);
    lua_pushvalue(L, -1);
    lua_setfield(L, -3, name);
    lua_remove(L, -2);
    return count;
}

static float opt_number(lua_State *L, int t, const char *name, float def, float lo, float hi) {
    lua_getfield(L, t, name);
    int ok = 1;
    lua_Number v = lua_isnil(L, -1) ? def : lua_tonumberx(L, -1, &ok);
    lua_pop(L, 1);
    if (!ok || !(v >= lo && v <= hi)) luaL_error(L, "audio: '%s' must be a number from %f to %f", name, (double)lo, (double)hi);
    return (float)v;
}

static bool opt_position(lua_State *L, int t, float out[3]) {
    if (lua_getfield(L, t, "position") == LUA_TNIL) {
        lua_pop(L, 1);
        return false;
    }
    if (!lua_istable(L, -1) || luaL_len(L, -1) != 3) luaL_error(L, "audio: 'position' must be a table of 3 numbers");
    for (int k = 0; k < 3; k++) {
        lua_rawgeti(L, -1, k + 1);
        int ok;
        lua_Number v = lua_tonumberx(L, -1, &ok);
        if (!ok || !isfinite(v)) luaL_error(L, "audio: 'position' must be a table of 3 numbers");
        out[k] = (float)v;
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
    return true;
}

static int bus_arg(lua_State *L, const char *name, bool master) {
    static const char *const names[] = {"sfx", "ui", "ambient", "music", "master", NULL};
    for (int i = 0; names[i]; i++)
        if (strcmp(name, names[i]) == 0 && (i < 3 || master)) return i == 4 ? -1 : i;
    return luaL_error(L, "audio: no bus named '%s'", name);
}

/* fk.audio.play(sound or name, { volume, pitch, pan, loop, position, bus }) -> voice id, or nil when all voices
   play loops. Named sounds pick a variation at random and vary their pitch by up to 4%. */
static int l_play(lua_State *L) {
    lua_settop(L, 2);
    bool named = lua_type(L, 1) == LUA_TSTRING;
    lua_sound *s;
    if (named) {
        int n = push_bank(L, lua_tostring(L, 1));
        lua_rawgeti(L, -1, (lua_Integer)fk_rng_below(&rng, (uint64_t)n) + 1);
        s = lua_touserdata(L, -1);
        lua_replace(L, 1); /* the chosen sound stays referenced at 1 */
        lua_pop(L, 1);
    } else {
        s = luaL_checkudata(L, 1, "fk.sound");
    }
    fk_voice_params p = {&s->sound, 1, 1, 0, false, false, {0, 0, 0}, FK_BUS_SFX};
    if (named) p.pitch = 0.96f + 0.08f * (float)fk_rng_float(&rng);
    if (!lua_isnil(L, 2)) {
        luaL_checktype(L, 2, LUA_TTABLE);
        p.volume = opt_number(L, 2, "volume", 1, 0, 4);
        p.pitch = opt_number(L, 2, "pitch", p.pitch, 0.25f, 4);
        p.pan = opt_number(L, 2, "pan", 0, -1, 1);
        lua_getfield(L, 2, "loop");
        p.loop = lua_toboolean(L, -1);
        lua_getfield(L, 2, "bus");
        if (!lua_isnil(L, -1)) p.bus = bus_arg(L, luaL_checkstring(L, -1), false);
        lua_pop(L, 2);
        p.spatial = opt_position(L, 2, p.position);
    }
    fk_platform_audio_lock();
    int id = fk_mixer_play(&p);
    fk_platform_audio_unlock();
    if (!id) return 0;
    /* the voice keeps its sound alive; finished voices let theirs go */
    lua_getfield(L, LUA_REGISTRYINDEX, "fk.voices");
    lua_pushnil(L);
    while (lua_next(L, -2)) {
        lua_pop(L, 1);
        fk_platform_audio_lock();
        bool alive = fk_mixer_alive((int)lua_tointeger(L, -1));
        fk_platform_audio_unlock();
        if (!alive) {
            lua_pushvalue(L, -1);
            lua_pushnil(L);
            lua_rawset(L, -4); /* clearing a field during traversal is allowed */
        }
    }
    lua_pushvalue(L, 1);
    lua_rawseti(L, -2, id);
    lua_pushinteger(L, id);
    return 1;
}

static int l_stop(lua_State *L) {
    int id = (int)luaL_checkinteger(L, 1);
    float fade = (float)luaL_optnumber(L, 2, 0);
    fk_platform_audio_lock();
    fk_mixer_stop(id, fade);
    fk_platform_audio_unlock();
    return 0;
}

/* fk.audio.set(id, { volume, pitch, position }): changes a playing voice (loops follow the game this way). */
static int l_set(lua_State *L) {
    int id = (int)luaL_checkinteger(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    float volume = 0, pitch = 0, position[3];
    lua_getfield(L, 2, "volume");
    lua_getfield(L, 2, "pitch");
    bool has_volume = !lua_isnil(L, -2), has_pitch = !lua_isnil(L, -1);
    lua_pop(L, 2);
    if (has_volume) volume = opt_number(L, 2, "volume", 1, 0, 4);
    if (has_pitch) pitch = opt_number(L, 2, "pitch", 1, 0.25f, 4);
    bool has_position = opt_position(L, 2, position);
    fk_platform_audio_lock();
    fk_mixer_set(id, has_volume ? &volume : NULL, has_pitch ? &pitch : NULL, has_position ? position : NULL);
    fk_platform_audio_unlock();
    return 0;
}

static int l_alive(lua_State *L) {
    fk_platform_audio_lock();
    lua_pushboolean(L, fk_mixer_alive((int)luaL_checkinteger(L, 1)));
    fk_platform_audio_unlock();
    return 1;
}

static int l_active(lua_State *L) {
    fk_platform_audio_lock();
    lua_pushinteger(L, fk_mixer_active());
    fk_platform_audio_unlock();
    return 1;
}

/* fk.audio.listener{ position = {x, y, z}, right = {x, y, z} }: where the ears are (usually the camera). */
static int l_listener(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    float position[3] = {0, 0, 0}, right[3] = {1, 0, 0};
    opt_position(L, 1, position);
    lua_getfield(L, 1, "right");
    if (!lua_isnil(L, -1)) {
        if (!lua_istable(L, -1) || luaL_len(L, -1) != 3) return luaL_error(L, "audio: 'right' must be a table of 3 numbers");
        for (int k = 0; k < 3; k++) {
            lua_rawgeti(L, -1, k + 1);
            right[k] = (float)luaL_checknumber(L, -1);
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
    fk_platform_audio_lock();
    fk_mixer_listener(position, right);
    fk_platform_audio_unlock();
    return 0;
}

static int l_volume(lua_State *L) {
    int bus = bus_arg(L, luaL_checkstring(L, 1), true);
    lua_Number v = luaL_checknumber(L, 2);
    luaL_argcheck(L, v >= 0 && v <= 2, 2, "the volume must be from 0 to 2");
    fk_platform_audio_lock();
    fk_mixer_volume(bus, (float)v);
    fk_platform_audio_unlock();
    return 0;
}

/* fk.audio.reverb{ room, damping, wet }: the space the listener is in (0..1 each). */
static int l_reverb(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    float room = opt_number(L, 1, "room", 0.5f, 0, 1), damping = opt_number(L, 1, "damping", 0.5f, 0, 1);
    float wet = opt_number(L, 1, "wet", 0.15f, 0, 1);
    fk_platform_audio_lock();
    fk_mixer_reverb(room, damping, wet);
    fk_platform_audio_unlock();
    return 0;
}

/* fk.audio.music(name, path[, volume]): a looping, streamed music track (48 kHz OGG), silent unless given a volume. */
static int l_music(lua_State *L) {
    const char *name = luaL_checkstring(L, 1), *rel = luaL_checkstring(L, 2);
    float volume = (float)luaL_optnumber(L, 3, 0);
    if (!valid_path(rel)) return luaL_error(L, "music: '%s' is not a path inside data/", rel);
    size_t size;
    void *ogg = fk_vfs_read(rel, &size);
    if (!ogg) return luaL_error(L, "music: %s: cannot find the file", rel);
    const char *why = NULL;
    fk_platform_audio_lock();
    bool ok = fk_mixer_track(name, ogg, size, volume, &why);
    fk_platform_audio_unlock();
    if (!ok) return luaL_error(L, "music: %s: %s", rel, why);
    return 0;
}

/* fk.audio.fade(name, volume, seconds): moves a music track's volume over time (crossfades). */
static int l_fade(lua_State *L) {
    const char *name = luaL_checkstring(L, 1);
    lua_Number v = luaL_checknumber(L, 2), seconds = luaL_optnumber(L, 3, 0);
    luaL_argcheck(L, v >= 0 && v <= 2, 2, "the volume must be from 0 to 2");
    fk_platform_audio_lock();
    bool ok = fk_mixer_fade(name, (float)v, (float)seconds);
    fk_platform_audio_unlock();
    if (!ok) return luaL_error(L, "fade: no music track named '%s'", name);
    return 0;
}

static int l_track_volume(lua_State *L) {
    fk_platform_audio_lock();
    float v = fk_mixer_track_volume(luaL_checkstring(L, 1));
    fk_platform_audio_unlock();
    if (v < 0) lua_pushnil(L);
    else lua_pushnumber(L, v);
    return 1;
}

void fk_lua_audio_open(lua_State *L) {
    static const luaL_Reg audio[] = {{"sound", l_sound},     {"play", l_play},       {"stop", l_stop},
                                     {"set", l_set},         {"alive", l_alive},     {"active", l_active},
                                     {"listener", l_listener}, {"volume", l_volume}, {"reverb", l_reverb},
                                     {"music", l_music},     {"fade", l_fade},       {"track_volume", l_track_volume},
                                     {NULL, NULL}};
    fk_rng_seed(&rng, 0x534f554e44ull);
    luaL_newmetatable(L, "fk.sound");
    lua_pushcfunction(L, l_sound_gc);
    lua_setfield(L, -2, "__gc");
    lua_createtable(L, 0, 1);
    lua_pushcfunction(L, l_sound_length);
    lua_setfield(L, -2, "length");
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    lua_newtable(L);
    lua_setfield(L, LUA_REGISTRYINDEX, "fk.sound_banks");
    lua_newtable(L);
    lua_setfield(L, LUA_REGISTRYINDEX, "fk.voices");
    luaL_newlib(L, audio);
}
