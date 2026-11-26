#include <math.h>
#include <string.h>

#include "core/mat4.h"
#include "gfx/frame.h"
#include "gfx/shadow.h"
#include "utest.h"

static void perspective(float m[16], float fovy, float aspect, float n, float f) {
    float t = 1.0f / tanf(fovy / 2);
    memset(m, 0, 16 * sizeof(float));
    m[0] = t / aspect, m[5] = t, m[10] = (f + n) / (n - f), m[11] = -1, m[14] = 2 * f * n / (n - f);
}

UTEST(mat4, multiply_inverse_point) {
    float a[16], b[16], c[16], inv[16], p[3] = {1, 2, 3}, q[3];
    fk_mat4_identity(a);
    a[12] = 5, a[13] = -2; /* translation */
    perspective(b, 1.0f, 1.5f, 0.1f, 100.0f);
    fk_mat4_mul(c, b, a);
    ASSERT_TRUE(fk_mat4_inverse(inv, c));
    fk_mat4_mul(c, c, inv); /* aliasing the output */
    for (int i = 0; i < 16; i++) EXPECT_NEAR(c[i], i % 5 == 0 ? 1.0f : 0.0f, 1e-4);
    fk_mat4_point(a, p, q);
    EXPECT_NEAR(q[0], 6.0f, 1e-6);
    EXPECT_NEAR(q[1], 0.0f, 1e-6);
    float zero[16] = {0};
    EXPECT_FALSE(fk_mat4_inverse(inv, zero));
}

UTEST(mat4, ortho_and_look) {
    float o[16], v[16], p[3], q[3];
    fk_mat4_ortho(o, -2, 2, -1, 1, 0, 10);
    p[0] = 2, p[1] = 1, p[2] = -10;
    fk_mat4_point(o, p, q);
    EXPECT_NEAR(q[0], 1.0f, 1e-6);
    EXPECT_NEAR(q[1], 1.0f, 1e-6);
    EXPECT_NEAR(q[2], 1.0f, 1e-6);
    float eye[3] = {0, 0, 5}, dir[3] = {0, 0, -2}, up[3] = {0, 1, 0};
    fk_mat4_look(v, eye, dir, up);
    p[0] = 0, p[1] = 0, p[2] = 0;
    fk_mat4_point(v, p, q);
    EXPECT_NEAR(q[2], -5.0f, 1e-6); /* the origin is 5 units in front of the camera */
}

UTEST(shadow, splits) {
    float prev = 0.1f;
    for (int i = 0; i < 4; i++) {
        float s = fk_shadow_split(i, 4, 0.1f, 1000.0f);
        EXPECT_GT(s, prev);
        prev = s;
    }
    EXPECT_NEAR(prev, FK_SHADOW_DISTANCE, 1e-3); /* capped at the shadow distance */
    EXPECT_NEAR(fk_shadow_split(0, 1, 0.1f, 20.0f), 20.0f, 1e-4);
}

static void cascade_for_camera(fk_cascade *c, float cx, const float to_light[3]) {
    float proj[16], view[16], vp[16], inv[16];
    perspective(proj, 0.8f, 16.0f / 9.0f, 0.1f, 100.0f);
    fk_mat4_identity(view);
    view[12] = -cx; /* camera moved to x = cx */
    fk_mat4_mul(vp, proj, view);
    fk_mat4_inverse(inv, vp);
    fk_shadow_cascade(c, inv, 0.1f, 100.0f, 0.1f, 10.0f, to_light, 1024);
}

UTEST(shadow, texel_snapping) {
    const float to_light[3] = {0.48f, 0.64f, 0.6f};
    fk_cascade first, prev, cur;
    cascade_for_camera(&first, 0.0f, to_light);
    EXPECT_GT(first.texel, 0.0f);
    EXPECT_NEAR(first.split, 10.0f, 1e-6);
    /* 20 camera steps of 1/40 texel (half a texel in all): without snapping every step would move the
       cascade; with snapping it changes at most once. */
    int changes = 0;
    prev = first;
    for (int i = 1; i <= 20; i++) {
        cascade_for_camera(&cur, first.texel * 0.025f * (float)i, to_light);
        changes += memcmp(prev.view_proj, cur.view_proj, sizeof cur.view_proj) != 0;
        prev = cur;
    }
    EXPECT_LE(changes, 1);
    const float up[3] = {0, 1, 0}; /* straight down needs a different up vector */
    cascade_for_camera(&cur, 0.0f, up);
    EXPECT_GT(cur.texel, 0.0f);
}

UTEST(frame, recording) {
    fk_frame_reset();
    fk_frame *f = fk_frame_get();
    EXPECT_NEAR(f->sun_dir[0] * f->sun_dir[0] + f->sun_dir[1] * f->sun_dir[1] + f->sun_dir[2] * f->sun_dir[2], 1.0f, 1e-5);
    fk_mesh mesh = {0};
    float m[16];
    fk_mat4_identity(m);
    fk_material mat = {0.5f, 1.0f, {1, 2, 3}};
    for (int i = 0; i < 200; i++) fk_frame_draw(&mesh, m, &mat); /* grows past the first allocation */
    fk_frame_overlay(&mesh, m);
    EXPECT_EQ(f->ndraws, 200);
    EXPECT_EQ(f->draws[199].material.emission[2], 3.0f);
    EXPECT_EQ(f->noverlays, 1);
    fk_point_light light = {{0, 0, 0}, {1, 1, 1}, 5};
    for (int i = 0; i < FK_MAX_LIGHTS + 5; i++) fk_frame_light(&light);
    EXPECT_EQ(f->nlights, FK_MAX_LIGHTS);
    fk_frame_begin();
    EXPECT_EQ(f->ndraws + f->noverlays + f->nlights, 0);
    EXPECT_NEAR(fk_srgb_to_linear(0.5f), 0.2176f, 1e-3);
    EXPECT_EQ(fk_srgb_to_linear(-1.0f), 0.0f);
}

UTEST(settings, validation) {
    fk_gfx_settings s;
    fk_gfx_settings_default(&s);
    EXPECT_TRUE(fk_gfx_settings_check(&s) == NULL);
    const struct {
        int *field;
        int bad;
        const char *name;
    } cases[] = {{&s.width, 10, "width"},
                 {&s.height, 9999, "height"},
                 {&s.supersample, 3, "supersample"},
                 {&s.shadow_cascades, 5, "shadow_cascades"},
                 {&s.shadow_size, 100, "shadow_size"},
                 {&s.ao_samples, 17, "ao_samples"},
                 {&s.max_lights, -1, "max_lights"}};
    for (size_t i = 0; i < sizeof cases / sizeof *cases; i++) {
        fk_gfx_settings_default(&s);
        *cases[i].field = cases[i].bad;
        EXPECT_STREQ(fk_gfx_settings_check(&s), cases[i].name);
    }
}

UTEST(upscale, rectangles_and_mapping) {
    int r[4];
    fk_gfx_upscale_rect(1920, 1080, 480, 270, r);
    EXPECT_TRUE(r[0] == 0 && r[1] == 0 && r[2] == 1920 && r[3] == 1080);
    fk_gfx_upscale_rect(2340, 1080, 480, 270, r); /* a phone in landscape: bars left and right */
    EXPECT_TRUE(r[0] == 210 && r[1] == 0 && r[2] == 1920 && r[3] == 1080);
    fk_gfx_upscale_rect(1000, 700, 480, 270, r); /* 2x, centred */
    EXPECT_TRUE(r[0] == 20 && r[1] == 80 && r[2] == 960 && r[3] == 540);
    fk_gfx_upscale_rect(240, 270, 480, 270, r); /* smaller than the image: scaled down to fit */
    EXPECT_TRUE(r[2] == 240 && r[3] == 135);
    fk_gfx_upscale_rect(2340, 1080, 480, 270, r);
    fk_gfx_set_window(2340, 1080, r);
    float x = 210.0f / 2340.0f, y = 0.5f, dx = 1.0f / 2340.0f, dy = 0;
    fk_gfx_map_point(&x, &y);
    EXPECT_NEAR(x, 0.0f, 1e-5); /* the left edge of the image */
    EXPECT_NEAR(y, 0.5f, 1e-5);
    fk_gfx_map_delta(&dx, &dy);
    EXPECT_NEAR(dx, 1.0f / 1920.0f, 1e-7);
    int identity[4] = {0, 0, 1, 1};
    fk_gfx_set_window(1, 1, identity);
}

UTEST(mesh, normals) {
    /* Two triangles sharing an edge, one flat and one folded up; plus a degenerate triangle. */
    float v[6 * 9] = {0};
    const float p[6][3] = {{0, 0, 0}, {1, 0, 0}, {0, 0, -1}, {1, 0, -1}, {5, 5, 5}, {5, 5, 5}};
    for (int i = 0; i < 6; i++) memcpy(&v[i * 9], p[i], sizeof p[i]);
    const uint32_t idx[9] = {0, 1, 2, 1, 3, 2, 4, 5, 4};
    fk_mesh_normals(v, 6, idx, 9);
    EXPECT_NEAR(v[0 * 9 + 7], 1.0f, 1e-6); /* both triangles face up */
    EXPECT_NEAR(v[1 * 9 + 7], 1.0f, 1e-6);
    EXPECT_NEAR(v[4 * 9 + 7], 1.0f, 1e-6); /* degenerate: up rather than zero */
}
