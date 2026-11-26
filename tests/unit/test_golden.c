#include <string.h>

#include "app/golden.h"
#include "utest.h"

#define W 20
#define H 10

static uint8_t a[W * H * 4], b[W * H * 4], d[W * H * 4];

UTEST(golden, counts_differing_pixels) {
    memset(a, 100, sizeof a);
    memset(b, 100, sizeof b);
    b[0] = 108;  /* within the tolerance */
    b[5] = 109;  /* pixel 1 differs */
    b[42] = 0;   /* pixel 10 differs */
    EXPECT_EQ(fk_image_diff(a, b, W, H, 8, d), 2);
    EXPECT_EQ(d[4], 255);
    EXPECT_EQ(d[0], 108 / 4); /* faded reference */
    EXPECT_EQ(fk_image_diff(a, b, W, H, 8, NULL), 2);
}

UTEST(golden, update_compare_and_fail) {
    const char *golden = "test-output/unit-golden.png";
    memset(a, 50, sizeof a);
    ASSERT_TRUE(fk_golden_check(golden, "test-output", "unit", a, W, H, true));
    EXPECT_TRUE(fk_golden_check(golden, "test-output", "unit", a, W, H, false));
    a[0] = 200; /* 1 of 200 pixels = 0.5%: still accepted */
    EXPECT_TRUE(fk_golden_check(golden, "test-output", "unit", a, W, H, false));
    a[4] = 200; /* 2 of 200 pixels = 1%: fails and writes a diff image */
    EXPECT_FALSE(fk_golden_check(golden, "test-output", "unit", a, W, H, false));
    EXPECT_FALSE(fk_golden_check(golden, "test-output", "unit", a, W / 2, H, false));
    EXPECT_FALSE(fk_golden_check("test-output/missing.png", "test-output", "unit", a, W, H, false));
    EXPECT_FALSE(fk_golden_check("no-such-dir/x.png", "test-output", "unit", a, W, H, true));
}
