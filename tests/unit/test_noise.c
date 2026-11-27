#include <math.h>
#include <string.h>

#include "core/rng.h"
#include "gen/noise.h"
#include "utest.h"

static fk_noise graph(const fk_noise_node *nodes, int n) {
    fk_noise g;
    memset(&g, 0, sizeof g);
    memcpy(g.nodes, nodes, (size_t)n * sizeof *nodes);
    g.count = n;
    return g;
}

#define NODE(op, a, b, c, p0, p1, p2, oct, seed) {op, {a, b, c}, {p0, p1, p2}, oct, seed}

UTEST(noise, perlin_is_smooth_bounded_and_seeded) {
    double lo = 0, hi = 0, worst_step = 0;
    for (int i = 0; i < 20000; i++) {
        double x = i * 0.0137, y = i * 0.0071 - 3, z = 1.5;
        double v = fk_perlin(1, x, y, z), w = fk_perlin(1, x + 1e-4, y, z);
        lo = fmin(lo, v), hi = fmax(hi, v), worst_step = fmax(worst_step, fabs(w - v));
    }
    EXPECT_GT(hi, 0.5);
    EXPECT_LT(lo, -0.5);
    EXPECT_LT(hi, 1.2);
    EXPECT_GT(lo, -1.2);
    EXPECT_LT(worst_step, 1e-3); /* continuous */
    EXPECT_EQ(fk_perlin(1, 2, 3, 4), 0.0); /* zero on the lattice */
    EXPECT_NE(fk_perlin(1, 0.3, 0.4, 0.5), fk_perlin(2, 0.3, 0.4, 0.5));
}

UTEST(noise, every_node) {
    const fk_noise_node nodes[] = {
        NODE(FK_N_FBM, -1, -1, -1, 2, 2, 0.5, 5, 7),        /* 0 */
        NODE(FK_N_RIDGED, -1, -1, -1, 3, 2, 0.5, 4, 8),     /* 1 */
        NODE(FK_N_BILLOW, -1, -1, -1, 2, 2, 0.5, 3, 9),     /* 2 */
        NODE(FK_N_CELLS, -1, -1, -1, 4, 0, 0, 0, 10),       /* 3 */
        NODE(FK_N_CELLS, -1, -1, -1, 4, 1, 0, 0, 10),       /* 4: edges */
        NODE(FK_N_CRATERS, -1, -1, -1, 6, 0.7, 0, 0, 11),   /* 5 */
        NODE(FK_N_PERLIN, -1, -1, -1, 1, 0, 0, 0, 12),      /* 6 */
        NODE(FK_N_WARP, 0, 6, -1, 0.4, 0, 0, 0, 0),          /* 7 */
        NODE(FK_N_ADD, 7, 1, -1, 0, 0, 0, 0, 0),             /* 8 */
        NODE(FK_N_SUB, 8, 2, -1, 0, 0, 0, 0, 0),             /* 9 */
        NODE(FK_N_MUL, 9, 3, -1, 0, 0, 0, 0, 0),             /* 10 */
        NODE(FK_N_MIN, 10, 4, -1, 0, 0, 0, 0, 0),            /* 11 */
        NODE(FK_N_MAX, 11, 5, -1, 0, 0, 0, 0, 0),            /* 12 */
        NODE(FK_N_LATITUDE, -1, -1, -1, 0, 0, 0, 0, 0),      /* 13 */
        NODE(FK_N_BLEND, 12, 0, 13, 0, 0, 0, 0, 0),          /* 14 */
        NODE(FK_N_SCALE, 14, -1, -1, 2, 0.1, 0, 0, 0),       /* 15 */
        NODE(FK_N_CLAMP, 15, -1, -1, -0.8, 0.8, 0, 0, 0),    /* 16 */
        NODE(FK_N_ABS, 16, -1, -1, 0, 0, 0, 0, 0),           /* 17 */
        NODE(FK_N_TERRACE, 17, -1, -1, 5, 0.5, 0, 0, 0),     /* 18 */
        NODE(FK_N_SMOOTH, 18, -1, -1, 0.1, 0.6, 0, 0, 0),    /* 19 */
        NODE(FK_N_CONST, -1, -1, -1, -0.5, 0, 0, 0, 0),      /* 20 */
        NODE(FK_N_ADD, 19, 20, -1, 0, 0, 0, 0, 0),           /* 21 */
        NODE(FK_N_POWER, 21, -1, -1, 1.5, 0, 0, 0, 0),       /* 22 */
    };
    fk_noise g = graph(nodes, 23);
    ASSERT_TRUE(fk_noise_check(&g) == NULL);
    uint64_t h = FK_HASH_INIT;
    double lo = 1e9, hi = -1e9;
    for (int i = 0; i < 2000; i++) {
        double a = i * 0.0031, x = cos(a * 7) * cos(a), y = sin(a), z = sin(a * 7) * cos(a);
        double v = fk_noise_eval(&g, x, y, z);
        ASSERT_TRUE(isfinite(v));
        lo = fmin(lo, v), hi = fmax(hi, v);
        h = fk_hash_bytes(h, &v, sizeof v);
    }
    EXPECT_GE(lo, -1.0);
    EXPECT_LE(hi, 1.0);
    EXPECT_LT(lo, hi);
    /* Recorded once; every platform must evaluate exactly these values. */
    EXPECT_EQ(h, 0xd8f65df438c9e605ull);
    for (int k = 0; k <= 5; k++) { /* each source alone */
        fk_noise one = graph(&nodes[k], 1);
        one.nodes[0].in[0] = -1;
        EXPECT_TRUE(isfinite(fk_noise_eval(&one, 0.3, 0.6, 0.2)));
    }
    fk_noise zero = graph(&nodes[20], 1);
    zero.nodes[0].p[0] = 0;
    fk_noise pw = graph(nodes, 0);
    pw.nodes[0] = zero.nodes[0];
    pw.nodes[1] = (fk_noise_node)NODE(FK_N_POWER, 0, -1, -1, 2, 0, 0, 0, 0);
    pw.count = 2;
    EXPECT_EQ(fk_noise_eval(&pw, 0, 0, 0), 0.0);
}

UTEST(noise, checks) {
    fk_noise g = graph(NULL, 0);
    EXPECT_STREQ(fk_noise_check(&g), "a graph needs 1 to 256 nodes");
    const fk_noise_node bad_in[] = {NODE(FK_N_ADD, 0, 0, -1, 0, 0, 0, 0, 0)};
    g = graph(bad_in, 1);
    EXPECT_STREQ(fk_noise_check(&g), "a node's input must be an earlier node");
    const fk_noise_node bad_oct[] = {NODE(FK_N_FBM, -1, -1, -1, 1, 2, 0.5, 0, 0)};
    g = graph(bad_oct, 1);
    EXPECT_STREQ(fk_noise_check(&g), "octaves must be from 1 to 16");
    const fk_noise_node bad_op[] = {NODE(99, -1, -1, -1, 0, 0, 0, 0, 0)};
    g = graph(bad_op, 1);
    EXPECT_STREQ(fk_noise_check(&g), "unknown node");
    const fk_noise_node bad_t[] = {NODE(FK_N_CONST, -1, -1, -1, 0, 0, 0, 0, 0), NODE(FK_N_TERRACE, 0, -1, -1, 0, 0, 0, 0, 0)};
    g = graph(bad_t, 2);
    EXPECT_STREQ(fk_noise_check(&g), "terrace steps must be at least 1");
    const fk_noise_node bad_s[] = {NODE(FK_N_CONST, -1, -1, -1, 0, 0, 0, 0, 0), NODE(FK_N_SMOOTH, 0, -1, -1, 1, 1, 0, 0, 0)};
    g = graph(bad_s, 2);
    EXPECT_STREQ(fk_noise_check(&g), "smooth needs two different edges");
}
