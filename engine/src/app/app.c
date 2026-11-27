#include "app/app.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "app/cli.h"
#include "app/golden.h"

#define FK_SCENARIO_JOBS 2 /* background jobs run per frame in test scenarios */
#include "assets/vfs.h"
#include "assets/watch.h"
#include "audio/mixer.h"
#include "core/jobs.h"
#include "fx/particles.h"
#include "gfx/frame.h"
#include "gfx/gfx.h"
#include "lauxlib.h"
#include "platform/platform.h"
#include "script/script.h"

/* Hot reload: desktop debug builds watch data/ while a window is open. */
#if !defined(NDEBUG) && !defined(__EMSCRIPTEN__)
#define FK_HOT_RELOAD 1
#else
#define FK_HOT_RELOAD 0
#endif

static struct {
    fk_options opt;
    lua_State *L;
    bool window, interactive, broken, started;
    int workers; /* job threads (0 on the web) */
    bool restart, reconfigure; /* hot reload: a script or a shader changed */
    bool audio;                /* a sound device is open; otherwise the mixer runs on frame time, silently */
    double audio_carry;        /* fraction of a sample frame not yet mixed (silent runs) */
    uint64_t last_poll_ns;
    int game_ref, step_ref, co_ref;
    double acc; /* real time not yet simulated, in seconds */
    lua_State *co;
    int frames_left, frame, max_frames;
    char golden_dir[1024];
    uint64_t last_ns;
    int exit_code;
} app;

static fk_status finish(int code) {
    app.exit_code = code;
    if (app.opt.scenario) fk_platform_report(code == 0 ? "passed" : "failed", code == 0 ? "" : fk_script_error());
    return code == 0 ? FK_DONE : FK_FAILED;
}

/* A script error: in an interactive window, show it and keep the window open; otherwise stop with exit code 1. */
static fk_status fail(void) {
    if (!app.interactive) return finish(1);
    fk_platform_message("Fukuruma script error", fk_script_error());
    app.broken = true;
    return FK_RUNNING;
}

int fk_ticks_due(double *acc, double dt, double *alpha) {
    *acc += dt;
    int n = (int)(*acc / FK_TICK + 1e-9); /* the epsilon absorbs rounding, e.g. (1/30) / (1/60) */
    if (n > FK_MAX_TICKS) {
        n = FK_MAX_TICKS;
        *acc = 0; /* drop the backlog: slow down rather than spiral */
    } else {
        *acc -= n * FK_TICK;
        if (*acc < 0) *acc = 0;
    }
    *alpha = *acc / FK_TICK;
    return n;
}

static bool sim_step(void) {
    lua_rawgeti(app.L, LUA_REGISTRYINDEX, app.step_ref);
    lua_rawgeti(app.L, LUA_REGISTRYINDEX, app.game_ref);
    return fk_script_call(app.L, 1, 0);
}

/* Calls game[name](a, b) with the non-negative arguments; a missing function is skipped. */
static bool call_game(const char *name, double a, double b) {
    lua_rawgeti(app.L, LUA_REGISTRYINDEX, app.game_ref);
    lua_getfield(app.L, -1, name);
    lua_remove(app.L, -2);
    if (lua_isnil(app.L, -1)) {
        lua_pop(app.L, 1);
        return true;
    }
    int n = 0;
    if (a >= 0) lua_pushnumber(app.L, a), n++;
    if (b >= 0) lua_pushnumber(app.L, b), n++;
    return fk_script_call(app.L, n, 0);
}

/* --- scenario helpers (t.frames, t.expect, t.screenshot) ------------------- */

static int t_frames(lua_State *L) {
    lua_Integer n = luaL_optinteger(L, 1, 1);
    luaL_argcheck(L, n >= 1, 1, "must be at least 1");
    lua_pushliteral(L, "frames");
    lua_pushinteger(L, n);
    return lua_yield(L, 2);
}

static int t_expect(lua_State *L) {
    if (lua_toboolean(L, 1)) return 0;
    luaL_where(L, 1);
    lua_pushfstring(L, "expectation failed: %s", luaL_optstring(L, 2, "(no message)"));
    lua_concat(L, 2);
    return lua_error(L);
}

static int t_screenshot(lua_State *L) {
    const char *name = luaL_checkstring(L, 1);
    luaL_argcheck(L, *name && strspn(name, "abcdefghijklmnopqrstuvwxyz0123456789_-") == strlen(name), 1,
                  "use lowercase letters, digits, '_' and '-'");
    lua_pushliteral(L, "screenshot");
    lua_pushvalue(L, 1);
    return lua_yield(L, 2);
}

static int t_key(lua_State *L) {
    fk_input_emulate_key(fk_script_control(L, 1, fk_input_key_code, "key"), lua_toboolean(L, 2));
    return 0;
}

static int t_mouse_button(lua_State *L) {
    fk_input_emulate_mouse_button((int)luaL_checkinteger(L, 1), lua_toboolean(L, 2));
    return 0;
}

static int t_mouse_move(lua_State *L) {
    fk_input_emulate_mouse_move((float)luaL_checknumber(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

static int t_gamepad_axis(lua_State *L) {
    fk_input_emulate_axis(fk_script_control(L, 1, fk_input_axis_code, "gamepad axis"), (float)luaL_checknumber(L, 2));
    return 0;
}

static int t_gamepad_button(lua_State *L) {
    fk_input_emulate_button(fk_script_control(L, 1, fk_input_button_code, "gamepad button"), lua_toboolean(L, 2));
    return 0;
}

/* t.touch(id, x, y) puts a finger down or moves it; t.touch(id) lifts it. */
static int t_touch(lua_State *L) {
    lua_Integer id = luaL_checkinteger(L, 1);
    bool down = !lua_isnoneornil(L, 2);
    fk_input_emulate_touch(id, down, (float)luaL_optnumber(L, 2, 0), (float)luaL_optnumber(L, 3, 0));
    return 0;
}

static int identity(lua_State *L) {
    lua_settop(L, 1);
    return 1;
}

static bool scenario_load(void) {
    lua_State *L = app.L;
    fk_script_push_env(L);
    lua_pushcfunction(L, identity);
    lua_setfield(L, -2, "scenario");
    lua_pop(L, 1);
    if (!fk_script_load_file(L, app.opt.scenario) || !fk_script_call(L, 0, 1)) return false;
    if (!lua_istable(L, -1) || lua_getfield(L, -1, "run") != LUA_TFUNCTION) {
        fk_script_set_error("scenario: the file must return scenario { run = function(t) ... end }");
        return false;
    }
    lua_getfield(L, -2, "seed");
    if (!app.opt.seed_given && lua_isinteger(L, -1)) fk_script_set_seed(L, (uint64_t)lua_tointeger(L, -1));
    lua_getfield(L, -3, "timeout_s");
    int has_timeout;
    lua_Number timeout = lua_tonumberx(L, -1, &has_timeout);
    app.max_frames = (int)((has_timeout ? timeout : 60) * 60);
    lua_pop(L, 2);
    app.co = lua_newthread(L);
    lua_insert(L, -2);
    lua_xmove(L, app.co, 1); /* run */
    static const luaL_Reg helpers[] = {{"frames", t_frames},         {"expect", t_expect},
                                       {"screenshot", t_screenshot}, {"key", t_key},
                                       {"mouse_button", t_mouse_button}, {"gamepad_axis", t_gamepad_axis},
                                       {"gamepad_button", t_gamepad_button}, {"touch", t_touch},
                                       {"mouse_move", t_mouse_move},
                                       {NULL, NULL}};
    luaL_newlib(L, helpers);
    lua_xmove(L, app.co, 1); /* t */
    app.co_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_pop(L, 1);
    const char *s = app.opt.scenario, *slash = strrchr(s, '/');
    snprintf(app.golden_dir, sizeof app.golden_dir, "%.*s../golden/", slash ? (int)(slash - s + 1) : 0, s);
    return true;
}

static bool screenshot(const char *name) {
#ifdef __EMSCRIPTEN__
    fk_log("screenshot '%s' skipped: browser rendering differs from the reference renderer", name);
    return true;
#else
    if (!app.window) {
        fk_log("screenshot '%s' skipped (no rendering)", name);
        return true;
    }
    int w = fk_gfx_settings_current()->width, h = fk_gfx_settings_current()->height; /* the internal image */
    uint8_t *pixels = malloc((size_t)w * h * 4);
    fk_gfx_read_pixels(pixels);
    char golden[1100];
    snprintf(golden, sizeof golden, "%s%s.png", app.golden_dir, name);
    bool ok = fk_golden_check(golden, "test-output", name, pixels, w, h, app.opt.update_golden);
    free(pixels);
    if (!ok) fk_script_set_error("screenshot does not match its reference image");
    return ok;
#endif
}

/* Runs the scenario after each frame. Returns -1 to continue, otherwise the exit code. */
static int scenario_step(void) {
    if (++app.frame > app.max_frames) {
        char msg[128];
        snprintf(msg, sizeof msg, "scenario timed out after %d frames", app.max_frames);
        fk_script_set_error(msg);
        return 2;
    }
    if (app.frames_left > 0 && --app.frames_left > 0) return -1;
    int nargs = app.started ? 0 : 1;
    app.started = true;
    for (;;) {
        int nres;
        int status = lua_resume(app.co, app.L, nargs, &nres);
        nargs = 0;
        if (status == LUA_OK) {
            fk_log("scenario passed");
            return 0;
        }
        if (status != LUA_YIELD) {
            luaL_traceback(app.L, app.co, lua_tostring(app.co, -1), 0);
            fk_script_set_error(lua_tostring(app.L, -1));
            lua_pop(app.L, 1);
            return 1;
        }
        bool frames = strcmp(lua_tostring(app.co, -2), "frames") == 0;
        if (frames) app.frames_left = (int)lua_tointeger(app.co, -1);
        bool ok = frames || screenshot(lua_tostring(app.co, -1));
        lua_pop(app.co, nres);
        if (!ok) return 1;
        if (frames) return -1;
    }
}

/* --- application ------------------------------------------------------------- */

static fk_status start_game(void);

static void changed(void *flag) { *(bool *)flag = true; }

static void watch_found(const char *path, void *flag) { fk_watch_add(path, changed, flag ? flag : &app.restart); }

/* Applies changed shaders (new pipeline) and scripts (the game starts again from main.lua). */
static fk_status hot_reload(void) {
    uint64_t now = fk_platform_ticks_ns();
    if (now - app.last_poll_ns < 500000000ull) return FK_RUNNING;
    app.last_poll_ns = now;
    fk_watch_poll();
    if (app.reconfigure && !app.restart) {
        app.reconfigure = false;
        fk_log("hot reload: shaders %s", fk_gfx_configure() ? "reloaded" : "failed (see above); fix and save again");
    }
    if (!app.restart) return FK_RUNNING;
    app.restart = app.reconfigure = app.broken = false;
    fk_log("hot reload: restarting the game from data/scripts/main.lua");
    fk_script_close(app.L);
    fk_frame_reset();
    fk_particles_reset();
    fk_platform_audio_lock();
    fk_mixer_reset();
    fk_platform_audio_unlock();
    app.L = fk_script_open(true, app.opt.seed, false);
    app.game_ref = app.step_ref = LUA_NOREF;
    app.acc = 0;
    fk_gfx_configure(); /* shaders may have changed too; main.lua applies its settings again */
    return start_game();
}

fk_status fk_app_init(int argc, char **argv, const char *base) {
    memset(&app, 0, sizeof app);
    fk_input_reset();
    fk_gfx_settings_default(fk_gfx_settings_current());
    fk_frame_reset();
    fk_particles_reset();
    fk_mixer_reset();
    app.game_ref = app.step_ref = app.co_ref = LUA_NOREF;
    if (!fk_cli_parse(argc, argv, &app.opt)) return finish(1);
    fk_vfs_init(base);
    /* scenarios: no workers, a fixed number of jobs per frame (below), so what is ready when is the same everywhere */
    app.workers = fk_jobs_start(app.opt.scenario ? 0 : -1);
    bool render = !app.opt.no_render && !app.opt.test_dir;
    app.L = fk_script_open(render, app.opt.seed, app.opt.coverage);
    if (app.opt.test_dir) return finish(fk_run_tests(app.L, app.opt.test_dir, app.opt.coverage) ? 0 : 1);
    if (app.opt.scenario && !scenario_load()) return finish(1);

    char path[1024];
    if (render) {
        if (!fk_platform_open(app.opt.headless)) return finish(1);
        app.window = true;
        if (!fk_gfx_init()) return finish(1);
    }
    app.interactive = app.window && !app.opt.headless && !app.opt.scenario;
    fk_storage_memory(!app.interactive); /* test runs must not read or change the player's settings */
    if (app.interactive) app.audio = fk_platform_audio_open(fk_mixer_mix); /* tests stay silent and reproducible */
    if (FK_HOT_RELOAD && app.interactive) {
        fk_platform_find_files(fk_vfs_path("scripts", path, sizeof path), ".lua", watch_found, NULL);
        fk_platform_find_files(fk_vfs_path("shaders", path, sizeof path), ".glsl", watch_found, &app.reconfigure);
    }
    return start_game();
}

/* Loads data/scripts/main.lua and the simulation module and calls game.init(). */
static fk_status start_game(void) {
    char path[1024];
    size_t size;
    char *code = fk_vfs_read("scripts/main.lua", &size);
    if (!code) {
        snprintf(path, sizeof path, "cannot find ");
        fk_vfs_path("scripts/main.lua", path + 12, sizeof path - 12);
        fk_script_set_error(path);
        return finish(1);
    }
    bool ok = fk_script_load(app.L, code, size, "@data/scripts/main.lua") && fk_script_call(app.L, 0, 1);
    fk_platform_free(code);
    if (!ok) return fail();
    if (!lua_istable(app.L, -1)) {
        lua_pop(app.L, 1);
        fk_script_set_error("data/scripts/main.lua must return a table with init, tick and draw functions");
        return fail();
    }
    lua_getfield(app.L, LUA_REGISTRYINDEX, "fk.loaded"); /* require("game") returns it (scenarios, mods) */
    lua_pushvalue(app.L, -2);
    lua_setfield(app.L, -2, "game");
    lua_pop(app.L, 1);
    app.game_ref = luaL_ref(app.L, LUA_REGISTRYINDEX);
    fk_script_push_env(app.L); /* the simulation module: fk.sim.step(game) runs one tick */
    lua_getfield(app.L, -1, "require");
    lua_remove(app.L, -2);
    lua_pushliteral(app.L, "fk.sim");
    if (!fk_script_call(app.L, 1, 1)) return fail();
    lua_getfield(app.L, -1, "step");
    lua_remove(app.L, -2);
    app.step_ref = luaL_ref(app.L, LUA_REGISTRYINDEX);
    app.last_ns = fk_platform_ticks_ns();
    return call_game("init", -1, -1) ? FK_RUNNING : fail();
}

fk_status fk_app_iterate(void) {
    int ticks = 1; /* headless runs and scenarios: one tick per frame, so they are reproducible */
    double alpha = 1.0, dt = FK_TICK;
    if (FK_HOT_RELOAD && app.interactive && hot_reload() != FK_RUNNING) return FK_FAILED;
    if (app.interactive) {
        uint64_t now = fk_platform_ticks_ns();
        dt = (double)(now - app.last_ns) / 1e9;
        ticks = fk_ticks_due(&app.acc, dt, &alpha);
        app.last_ns = now;
    }
    if (app.broken) {
        fk_gfx_clear_window(0.25f, 0.0f, 0.0f);
        fk_platform_swap();
        return FK_RUNNING;
    }
    fk_script_frame_begin(app.L);
    if (app.opt.scenario) fk_jobs_run(FK_SCENARIO_JOBS);
    else if (!app.workers) fk_jobs_update(2000000); /* no worker threads (the web): 2 ms of background work per frame */
    if (!call_game("input", -1, -1)) return fail();
    for (int i = 0; i < ticks; i++)
        if (!sim_step()) return fail();
    double frame_dt = dt < 0.25 ? dt : 0.25; /* presentation time: a long hitch (loading, a hidden tab) is not replayed */
    if (!call_game("draw", alpha, frame_dt)) return fail();
    if (app.window) {
        int w, h;
        fk_platform_size(&w, &h);
        fk_gfx_render(frame_dt, w, h);
    }
    fk_input_frame_end(); /* before the scenario, so its emulated input (mouse motion too) reaches the next frame */
    if (app.co) {
        int code = scenario_step();
        if (code >= 0) return finish(code);
    }
    if (!app.audio) { /* silent runs: voices still start and end on time */
        float scratch[512 * 2];
        app.audio_carry += frame_dt * FK_AUDIO_RATE;
        for (int n = (int)app.audio_carry; n > 0; n -= 512) fk_mixer_mix(scratch, n < 512 ? n : 512);
        app.audio_carry -= (int)app.audio_carry;
    }
    if (app.window) fk_platform_swap();
    return FK_RUNNING;
}

int fk_app_quit(void) {
    fk_jobs_stop(); /* first: jobs may write into memory the scripts own */
    fk_script_close(app.L); /* first: meshes are freed while the GL context still exists */
    fk_watch_clear();
    fk_platform_audio_close();
    fk_mixer_reset();
    if (app.window) {
        fk_gfx_shutdown();
        fk_platform_close();
    }
    int code = app.exit_code;
    memset(&app, 0, sizeof app);
    return code;
}
