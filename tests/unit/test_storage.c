#include <string.h>

#include "lauxlib.h"
#include "script/script.h"
#include "utest.h"

static bool run(lua_State *L, const char *code) {
    return fk_script_load(L, code, strlen(code), "=test") && fk_script_call(L, 0, 0);
}

UTEST(storage, files_and_memory) {
    lua_State *L = fk_script_open(false, 1, false);
    fk_storage_memory(false); /* the user's application-data folder: a fixed test value, overwritten each run */
    EXPECT_TRUE(run(L, "fk.storage.save('fk_unit_test', 'a=1\\n'); assert(fk.storage.load('fk_unit_test') == 'a=1\\n')"));
    EXPECT_TRUE(run(L, "assert(fk.storage.load('fk_unit_test_never_saved') == nil)"));
    fk_storage_memory(true);
    EXPECT_TRUE(run(L, "assert(fk.storage.load('fk_unit_test') == nil, 'memory mode does not see files')"));
    EXPECT_TRUE(run(L, "fk.storage.save('x', 'y'); assert(fk.storage.load('x') == 'y')"));
    EXPECT_FALSE(run(L, "fk.storage.save('../evil', 'y')"));
    EXPECT_TRUE(strstr(fk_script_error(), "not a valid name") != NULL);
    fk_script_close(L);
}
