#include <math.h>
#include <string.h>

#include "anim/anim.h"
#include "assets/vfs.h"
#include "gfx/frame.h"
#include "utest.h"

static bool load_clip_fixture(fk_model *m) {
    char error[256];
    fk_vfs_init(FK_TESTS_DIR "/fixtures/assets/");
    return fk_model_load(m, "models/clip.glb", error, sizeof error);
}

UTEST(anim, sampling) {
    fk_model m;
    ASSERT_TRUE(load_clip_fixture(&m));
    fk_trs pose[8];
    ASSERT_LE(m.node_count, 8);
    int a = fk_model_node(&m, "a"), b = fk_model_node(&m, "b");
    fk_pose_rest(&m, pose);
    EXPECT_NEAR(pose[b].t[1], 1.0f, 1e-6);

    int step = fk_model_clip(&m, "step"); /* b.translation: (0,1,0) at 0, (0,2,0) at 1, step keys */
    fk_clip_sample(&m, step, 0.99f, pose);
    EXPECT_NEAR(pose[b].t[1], 1.0f, 1e-6);
    fk_clip_sample(&m, step, 1.0f, pose);
    EXPECT_NEAR(pose[b].t[1], 2.0f, 1e-6);
    fk_clip_sample(&m, step, -5.0f, pose); /* clamped */
    EXPECT_NEAR(pose[b].t[1], 1.0f, 1e-6);

    int linear = fk_model_clip(&m, "linear"); /* a.scale: 1, 2, 1 at 0, 0.5, 1 */
    fk_clip_sample(&m, linear, 0.25f, pose);
    EXPECT_NEAR(pose[a].s[0], 1.5f, 1e-6);
    fk_clip_sample(&m, linear, 7.0f, pose);
    EXPECT_NEAR(pose[a].s[2], 1.0f, 1e-6);

    int cubic = fk_model_clip(&m, "cubic"); /* b.rotation: 0 to 90 degrees about x over 2 s, zero tangents */
    fk_clip_sample(&m, cubic, 1.0f, pose);
    EXPECT_NEAR(pose[b].r[0], sinf(0.3926991f), 2e-3); /* zero tangents: halfway in time is halfway in value */
    fk_clip_sample(&m, cubic, 0.5f, pose);
    EXPECT_LT(pose[b].r[0], sinf(0.3926991f) * 0.5f); /* eases in */
    fk_clip_sample(&m, cubic, 2.0f, pose);
    EXPECT_NEAR(pose[b].r[0], sinf(0.785398f), 1e-5);
    fk_model_free(&m);
}

UTEST(anim, blending_additive_and_globals) {
    fk_model m;
    ASSERT_TRUE(load_clip_fixture(&m));
    int b = fk_model_node(&m, "b"), cubic = fk_model_clip(&m, "cubic");
    fk_trs rest[8], turned[8], mix[8];
    fk_pose_rest(&m, rest);
    fk_pose_rest(&m, turned);
    fk_clip_sample(&m, cubic, 2.0f, turned); /* b turned 90 degrees about x */
    turned[b].t[1] = 3;
    fk_pose_blend(rest, turned, 0.5f, mix, m.node_count);
    EXPECT_NEAR(mix[b].t[1], 2.0f, 1e-6);
    EXPECT_NEAR(mix[b].r[0], sinf(0.3926991f), 1e-5); /* 45 degrees */
    for (int k = 0; k < 4; k++) turned[b].r[k] = -turned[b].r[k]; /* the same rotation, the other hemisphere */
    fk_pose_blend(rest, turned, 0.5f, mix, m.node_count);
    EXPECT_NEAR(fabsf(mix[b].r[0]), sinf(0.3926991f), 1e-5); /* still the short way */

    /* additive: the layer's difference from the rest pose, scaled by the weight */
    fk_trs pose[8], layer[8];
    fk_pose_rest(&m, pose);
    fk_pose_rest(&m, layer);
    layer[b].t[1] += 2;
    layer[b].s[0] = 3;
    fk_clip_sample(&m, cubic, 2.0f, layer);
    fk_pose_add(&m, pose, layer, 0.5f);
    EXPECT_NEAR(pose[b].t[1], 2.0f, 1e-6);
    EXPECT_NEAR(pose[b].s[0], 2.0f, 1e-6);
    EXPECT_NEAR(pose[b].r[0], sinf(0.3926991f), 1e-5);

    /* globals: b sits 1 above a; a raised by 2 moves b with it */
    float g[8 * 16];
    fk_pose_rest(&m, pose);
    int a = fk_model_node(&m, "a");
    pose[a].t[1] = 2;
    fk_pose_globals(&m, pose, g);
    EXPECT_NEAR(g[b * 16 + 13], 3.0f, 1e-6);
    fk_model_free(&m);
}

UTEST(anim, frame_bones) {
    fk_frame_reset();
    float bones[16 * 64];
    memset(bones, 0, sizeof bones);
    bones[16 * 63 + 15] = 7;
    int first = fk_frame_bones(bones, 64);
    EXPECT_EQ(first, 0);
    EXPECT_EQ(fk_frame_bones(bones, 64), 64);
    EXPECT_EQ(fk_frame_get()->bones[127 * 16 + 15], 7.0f);
    while (fk_frame_bones(bones, 64) >= 0) {
    }
    EXPECT_EQ(fk_frame_get()->nbones, FK_MAX_FRAME_BONES); /* full: further skinned draws use their bind pose */
    fk_mesh mesh = {0};
    fk_material mat;
    fk_material_default(&mat);
    float id[16] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
    fk_frame_draw_skinned(&mesh, id, &mat, 64);
    fk_frame_draw(&mesh, id, &mat);
    EXPECT_EQ(fk_frame_get()->draws[0].bone_offset, 64);
    EXPECT_EQ(fk_frame_get()->draws[1].bone_offset, -1);
    fk_frame_begin();
    EXPECT_EQ(fk_frame_get()->nbones, 0);
}
