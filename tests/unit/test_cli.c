#include "app/cli.h"
#include "utest.h"

#define PARSE(o, ...)                                                                                                  \
    fk_cli_parse(sizeof((char *[]){"fukuruma", __VA_ARGS__}) / sizeof(char *), (char *[]){"fukuruma", __VA_ARGS__}, &o)

UTEST(cli, defaults) {
    fk_options o;
    char *argv[] = {"fukuruma"};
    ASSERT_TRUE(fk_cli_parse(1, argv, &o));
    EXPECT_EQ(o.seed, 1u);
    EXPECT_FALSE(o.headless || o.no_render || o.seed_given);
    EXPECT_TRUE(o.scenario == NULL && o.test_dir == NULL);
}

UTEST(cli, all_options) {
    fk_options o;
    ASSERT_TRUE(PARSE(o, "--headless", "--no-render", "--update-golden", "--coverage", "--test", "t", "--scenario", "s.lua",
                      "--seed", "18446744073709551615", "-psn_0_123"));
    EXPECT_TRUE(o.headless && o.no_render && o.update_golden && o.coverage && o.seed_given);
    EXPECT_STREQ(o.test_dir, "t");
    EXPECT_STREQ(o.scenario, "s.lua");
    EXPECT_EQ(o.seed, 18446744073709551615u);
}

UTEST(cli, rejects_bad_input) {
    fk_options o;
    EXPECT_FALSE(PARSE(o, "--seed", "-1"));
    EXPECT_FALSE(PARSE(o, "--seed", "12x"));
    EXPECT_FALSE(PARSE(o, "--seed", "99999999999999999999"));
    EXPECT_FALSE(PARSE(o, "--scenario"));
    EXPECT_FALSE(PARSE(o, "--frobnicate"));
}
