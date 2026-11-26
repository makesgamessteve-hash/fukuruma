#include "app/app.h"
#include "utest.h"

#define DATA FK_TESTS_DIR "/../"
#define FIX FK_TESTS_DIR "/fixtures/"

static int run(const char *base, int argc, char **argv) {
    fk_status s = fk_app_init(argc, argv, base);
    for (int i = 0; s == FK_RUNNING && i < 600; i++) s = fk_app_iterate();
    return fk_app_quit();
}

#define RUN(base, ...) run(base, sizeof((char *[]){"fukuruma", __VA_ARGS__}) / sizeof(char *), (char *[]){"fukuruma", __VA_ARGS__})

UTEST(app, scenarios) {
    EXPECT_EQ(RUN(DATA, "--no-render", "--scenario", FK_TESTS_DIR "/game/boot.lua"), 0);
    EXPECT_EQ(RUN(DATA, "--no-render", "--scenario", FIX "scenarios/pass.lua"), 0);
    EXPECT_EQ(RUN(DATA, "--no-render", "--scenario", FIX "scenarios/seed.lua"), 0);
    EXPECT_EQ(RUN(DATA, "--no-render", "--seed", "5", "--scenario", FIX "scenarios/seed.lua"), 1);
    EXPECT_EQ(RUN(DATA, "--no-render", "--scenario", FIX "scenarios/expect_fail.lua"), 1);
    EXPECT_EQ(RUN(DATA, "--no-render", "--scenario", FIX "scenarios/error.lua"), 1);
    EXPECT_EQ(RUN(DATA, "--no-render", "--scenario", FIX "scenarios/bad_name.lua"), 1);
    EXPECT_EQ(RUN(DATA, "--no-render", "--scenario", FIX "scenarios/timeout.lua"), 2);
    EXPECT_EQ(RUN(DATA, "--no-render", "--scenario", FIX "scenarios/not_table.lua"), 1);
    EXPECT_EQ(RUN(DATA, "--no-render", "--scenario", FIX "scenarios/no_run.lua"), 1);
    EXPECT_EQ(RUN(DATA, "--no-render", "--scenario", FIX "scenarios/missing.lua"), 1);
    EXPECT_EQ(RUN(DATA, "--no-render", "--scenario", "pass.lua"), 1); /* a path without folders */
}

UTEST(app, lua_tests) {
    EXPECT_EQ(RUN(DATA, "--test", FIX "luatests_ok"), 0);
    EXPECT_EQ(RUN(DATA, "--test", FIX "luatests_mixed"), 1);
    EXPECT_EQ(RUN(DATA, "--test", FIX "does-not-exist"), 1);
}

UTEST(app, game_errors_stop_non_interactive_runs) {
    EXPECT_EQ(RUN(DATA, "--no-render"), 0); /* the real game keeps running until it is stopped */
    EXPECT_EQ(RUN(FIX "update_error/", "--no-render"), 1);
    EXPECT_EQ(RUN(FIX "not_table/", "--no-render"), 1);
    EXPECT_EQ(RUN(FIX "syntax_error/", "--no-render"), 1);
    EXPECT_EQ(RUN(FIX "nothing/", "--no-render"), 1);
    EXPECT_EQ(RUN(DATA, "--bogus"), 1);
}
