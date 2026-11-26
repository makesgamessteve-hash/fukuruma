#include <string.h>

#include "assets/vfs.h"
#include "lauxlib.h"
#include "script/script.h"
#include "utest.h"

static bool run(lua_State *L, const char *code) {
    return fk_script_load(L, code, strlen(code), "=test") && fk_script_call(L, 0, 0);
}

UTEST(script, runs_code_in_the_sandbox) {
    lua_State *L = fk_script_open(false, 9, false);
    EXPECT_TRUE(run(L, "assert(fk.seed() == 9 and io == nil and _G == _ENV)"));
    fk_script_set_seed(L, 10);
    EXPECT_TRUE(run(L, "assert(fk.seed() == 10)"));
    fk_script_push_env(L);
    EXPECT_TRUE(lua_istable(L, -1));
    fk_script_close(L);
}

UTEST(script, reports_errors_with_a_traceback) {
    lua_State *L = fk_script_open(false, 1, false);
    EXPECT_FALSE(run(L, "local function f() error('deep') end f()"));
    EXPECT_TRUE(strstr(fk_script_error(), "deep") != NULL);
    EXPECT_TRUE(strstr(fk_script_error(), "traceback") != NULL);
    EXPECT_FALSE(run(L, "this is not lua"));
    EXPECT_TRUE(strstr(fk_script_error(), "syntax error") != NULL || strstr(fk_script_error(), "expected") != NULL);
    EXPECT_FALSE(run(L, "error({})")); /* non-string error values are reported too */
    EXPECT_FALSE(fk_script_load_file(L, FK_TESTS_DIR "/no-such-file.lua"));
    EXPECT_TRUE(strstr(fk_script_error(), "cannot read") != NULL);
    fk_script_close(L);
    fk_script_close(NULL);
}

UTEST(script, coverage_mode_opens_host_libraries_only) {
    lua_State *L = fk_script_open(false, 1, true);
    lua_getglobal(L, "debug");
    EXPECT_TRUE(lua_istable(L, -1));
    lua_pop(L, 1);
    EXPECT_TRUE(run(L, "assert(debug == nil and io == nil)"));
    fk_script_close(L);
}

UTEST(script, require_without_a_result_gives_true) {
    lua_State *L = fk_script_open(false, 1, false);
    fk_vfs_init(FK_TESTS_DIR "/fixtures/require/");
    EXPECT_TRUE(run(L, "assert(require('empty') == true)"));
    fk_script_close(L);
}
