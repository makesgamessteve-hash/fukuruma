#include <string.h>

#include "assets/vfs.h"
#include "platform/platform.h"
#include "utest.h"

static void count(const char *path, void *user) {
    (void)path;
    (*(int *)user)++;
}

UTEST(platform, finds_files_recursively) {
    int n = 0;
    fk_platform_find_files(FK_TESTS_DIR "/fixtures/luatests_mixed", "_test.lua", count, &n);
    EXPECT_EQ(n, 3);
    n = 0;
    fk_platform_find_files(FK_TESTS_DIR "/does-not-exist", "_test.lua", count, &n);
    EXPECT_EQ(n, 0);
}

UTEST(platform, writes_and_reads_files) {
    ASSERT_TRUE(fk_platform_make_dir("test-output"));
    ASSERT_TRUE(fk_platform_write_file("test-output/unit.txt", "hello", 5));
    size_t size;
    char *data = fk_platform_read_file("test-output/unit.txt", &size);
    ASSERT_TRUE(data != NULL);
    EXPECT_EQ(size, 5u);
    EXPECT_STREQ(data, "hello");
    fk_platform_free(data);
    EXPECT_TRUE(fk_platform_read_file("test-output/missing.txt", &size) == NULL);
    EXPECT_GT(fk_platform_ticks_ns(), 0u);
    fk_platform_report("passed", ""); /* no-op outside the browser */
}

UTEST(vfs, resolves_beside_the_base) {
    char buf[256];
    fk_vfs_init("/opt/fukuruma/");
    EXPECT_STREQ(fk_vfs_path("scripts/main.lua", buf, sizeof buf), "/opt/fukuruma/data/scripts/main.lua");
    fk_vfs_init(NULL);
    EXPECT_STREQ(fk_vfs_path("x", buf, sizeof buf), "data/x");
    fk_vfs_init(FK_TESTS_DIR "/../");
    size_t size;
    char *code = fk_vfs_read("scripts/main.lua", &size);
    ASSERT_TRUE(code != NULL);
    EXPECT_TRUE(strstr(code, "init") != NULL);
    fk_platform_free(code);
    EXPECT_TRUE(fk_vfs_read("scripts/missing.lua", &size) == NULL);
}
