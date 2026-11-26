#include <string.h>

#include "app/app.h"
#include "core/rng.h"
#include "utest.h"

/* The key hashing fk.rng uses for world seed 1 and the key "test". */
static uint64_t test_seed(void) {
    uint64_t h = fk_hash_u64(FK_HASH_INIT, 1);
    h = fk_hash_u64(fk_hash_bytes(h, "s", 1), 4);
    return fk_mix64(fk_hash_bytes(h, "test", 4));
}

UTEST(rng, recorded_sequence) {
    fk_rng r;
    fk_rng_seed(&r, test_seed());
    /* Recorded once; every platform must produce exactly these numbers. */
    EXPECT_EQ(fk_rng_next(&r), 7782953607450231717ull);
    EXPECT_EQ(fk_rng_next(&r), 340023469424535954ull);
    EXPECT_EQ(fk_rng_next(&r), 885364895529590449ull);
}

UTEST(rng, floats_and_ranges) {
    fk_rng r;
    fk_rng_seed(&r, 42);
    for (int i = 0; i < 10000; i++) {
        double f = fk_rng_float(&r);
        ASSERT_TRUE(f >= 0.0 && f < 1.0);
        ASSERT_LT(fk_rng_below(&r, 6), 6u);
    }
    EXPECT_EQ(fk_rng_below(&r, 1), 0u);
}

UTEST(rng, hashing) {
    EXPECT_EQ(fk_hash_bytes(FK_HASH_INIT, "", 0), FK_HASH_INIT);
    EXPECT_EQ(fk_hash_bytes(FK_HASH_INIT, "a", 1), 0xaf63dc4c8601ec8cull); /* FNV-1a 64 reference value */
    EXPECT_NE(fk_hash_u64(FK_HASH_INIT, 1), fk_hash_u64(FK_HASH_INIT, 2));
    EXPECT_NE(fk_mix64(1), fk_mix64(2));
}

UTEST(ticks, due_per_frame) {
    double acc = 0, alpha = -1;
    EXPECT_EQ(fk_ticks_due(&acc, 1.0 / 30.0, &alpha), 2); /* slow display */
    EXPECT_NEAR(alpha, 0.0, 1e-9);
    EXPECT_EQ(fk_ticks_due(&acc, 1.0 / 120.0, &alpha), 0); /* fast display */
    EXPECT_NEAR(alpha, 0.5, 1e-9);
    EXPECT_EQ(fk_ticks_due(&acc, 1.0 / 120.0, &alpha), 1);
    EXPECT_NEAR(alpha, 0.0, 1e-9);
    EXPECT_EQ(fk_ticks_due(&acc, 1.0, &alpha), FK_MAX_TICKS); /* long stall: the backlog is dropped */
    EXPECT_EQ(acc, 0.0);
    EXPECT_EQ(fk_ticks_due(&acc, 0.0, &alpha), 0);
}
