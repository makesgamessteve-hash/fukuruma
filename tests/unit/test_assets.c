#include <math.h>
#include <stdio.h>
#include <string.h>

#include "assets/image.h"
#include "assets/model.h"
#include "assets/sound.h"
#include "assets/vfs.h"
#include "assets/watch.h"
#include "core/mat4.h"
#include "script/script.h"
#include "platform/platform.h"
#include "utest.h"

#define ASSETS FK_TESTS_DIR "/fixtures/assets/"

static void *read_fixture(const char *rel, size_t *size) {
    fk_vfs_init(ASSETS);
    return fk_vfs_read(rel, size);
}

UTEST(image, png_jpeg_and_failures) {
    size_t size;
    int w, h;
    const char *why = NULL;
    void *file = read_fixture("textures/checker.png", &size);
    ASSERT_TRUE(file != NULL);
    uint8_t *px = fk_image_decode(file, size, &w, &h, &why);
    ASSERT_TRUE(px != NULL);
    EXPECT_EQ(w, 8);
    EXPECT_EQ(px[0], 255);  /* top-left is an "on" square */
    EXPECT_EQ(px[4 + 0], 0); /* the next pixel is "off" */
    fk_image_free(px);
    fk_platform_free(file);

    file = read_fixture("textures/checker.jpg", &size);
    px = fk_image_decode(file, size, &w, &h, &why);
    ASSERT_TRUE(px != NULL);
    EXPECT_EQ(h, 8);
    EXPECT_EQ(px[3], 255); /* JPEG has no alpha: opaque */
    fk_image_free(px);
    fk_platform_free(file);

    file = read_fixture("textures/broken.png", &size);
    EXPECT_TRUE(fk_image_decode(file, size, &w, &h, &why) == NULL);
    EXPECT_STREQ(why, "not a PNG or JPEG image");
    fk_platform_free(file);
    file = read_fixture("textures/wide.png", &size);
    EXPECT_TRUE(fk_image_decode(file, size, &w, &h, &why) == NULL);
    EXPECT_STREQ(why, "larger than 8192 pixels on a side");
    fk_platform_free(file);
}

static bool load(fk_model *m, const char *rel, char *error) {
    fk_vfs_init(ASSETS);
    return fk_model_load(m, rel, error, 256);
}

UTEST(model, separate_files_materials_and_nodes) {
    fk_model m;
    char error[256];
    ASSERT_TRUE(load(&m, "models/tri.gltf", error));
    EXPECT_EQ(m.node_count, 5);
    EXPECT_EQ(m.primitive_count, 1);
    EXPECT_EQ(m.texture_count, 1);
    EXPECT_EQ(m.images[0].width, 8);
    EXPECT_TRUE(m.images[0].srgb); /* used as base colour */
    const fk_model_material *mat = &m.materials[0];
    EXPECT_NEAR(mat->base[1], 0.5f, 1e-6);
    EXPECT_NEAR(mat->roughness, 0.25f, 1e-6);
    EXPECT_NEAR(mat->emission[2], 4.0f, 1e-5); /* KHR_materials_emissive_strength */
    EXPECT_NEAR(mat->normal_scale, 0.5f, 1e-6);
    EXPECT_EQ(mat->normal_tex, 0);
    const fk_primitive *p = &m.primitives[0];
    EXPECT_EQ(p->vertex_count, 3);
    EXPECT_NEAR(p->vertices[0].color[0], 1.0f, 1e-6); /* red vertex */
    EXPECT_NEAR(p->vertices[0].normal[2], 1.0f, 1e-6); /* computed: the file has no normals */
    EXPECT_NEAR(p->vertices[0].tangent[0], 1.0f, 1e-6); /* computed for the normal map */
    /* child: matrix node under a translated, rotated (90 degrees about x) and scaled parent */
    int child = fk_model_node(&m, "child");
    ASSERT_EQ(child, 1);
    EXPECT_EQ(m.nodes[child].parent, 0);
    EXPECT_NEAR(m.nodes[child].translation[0], 3.0f, 1e-6);
    EXPECT_NEAR(m.nodes[child].rotation[0], sinf(0.785398f), 1e-5); /* the matrix rotates 90 degrees about x */
    EXPECT_NEAR(m.nodes[child].global[12], 6.0f, 1e-5);              /* 3 * scale 2 */
    EXPECT_NEAR(m.nodes[child].global[13], 1.0f, 1e-5);
    /* 180 degree turns about x, y and z (matrices whose trace is -1) */
    for (int k = 0; k < 3; k++) {
        const char *names[3] = {"flip_x", "flip_y", "flip_z"};
        int n = fk_model_node(&m, names[k]);
        ASSERT_GE(n, 0);
        EXPECT_NEAR(fabsf(m.nodes[n].rotation[k]), 1.0f, 1e-6);
        EXPECT_NEAR(m.nodes[n].rotation[3], 0.0f, 1e-6);
    }
    EXPECT_EQ(fk_model_node(&m, "nobody"), -1);
    EXPECT_EQ(fk_model_clip(&m, "walk"), -1);
    fk_model_free(&m);
    EXPECT_EQ(m.node_count, 0);
}

UTEST(model, data_uris_and_defaults) {
    fk_model m;
    char error[256];
    ASSERT_TRUE(load(&m, "models/embedded.gltf", error));
    EXPECT_EQ(m.primitive_count, 2);
    EXPECT_EQ(m.primitives[0].index_count, 3); /* generated: no indices in the file */
    EXPECT_EQ(m.primitives[1].material, -1);
    EXPECT_FALSE(m.images[0].srgb); /* only used as a normal map */
    EXPECT_NEAR(m.primitives[1].vertices[2].weights[0], 1.0f, 1e-6);
    fk_model_free(&m);
}

UTEST(model, skins_and_clips) {
    fk_model m;
    char error[256];
    ASSERT_TRUE(load(&m, "models/clip.glb", error));
    EXPECT_EQ(m.skin_count, 1);
    EXPECT_EQ(m.skins[0].joint_count, 2);
    EXPECT_NEAR(m.skins[0].inverse_bind[16 + 13], -1.0f, 1e-6);
    EXPECT_EQ(m.clip_count, 4);
    int step = fk_model_clip(&m, "step"), cubic = fk_model_clip(&m, "cubic");
    ASSERT_GE(step, 0);
    EXPECT_EQ(m.clips[step].channels[0].interpolation, FK_INTERP_STEP);
    EXPECT_EQ(m.clips[cubic].channels[0].interpolation, FK_INTERP_CUBIC);
    EXPECT_EQ(m.clips[cubic].channels[0].path, FK_PATH_ROTATION);
    EXPECT_NEAR(m.clips[cubic].duration, 2.0f, 1e-6);
    EXPECT_EQ(m.clips[fk_model_clip(&m, "linear")].channels[0].path, FK_PATH_SCALE);
    EXPECT_STREQ(m.clips[3].name, "clip4"); /* unnamed */
    EXPECT_NEAR(m.primitives[0].vertices[0].joints[1], 1.0f, 1e-6);
    fk_model_free(&m);
}

UTEST(model, failures) {
    static const struct {
        const char *rel, *message;
    } cases[] = {
        {"models/none.glb", "cannot find models/none.glb"},
        {"models/not_gltf.glb", "not a valid glTF file"},
        {"models/truncated.glb", "not a valid glTF file"},
        {"models/line.gltf", "only triangle meshes are supported"},
        {"models/missing.gltf", "a file it refers to is missing"},
        {"models/escape.gltf", "it refers to a file outside data/"},
        {"models/bad_index.gltf", "not a valid glTF file"},
        {"models/missing_image.gltf", "image 'no_such_image.png' cannot be read"},
    };
    for (size_t i = 0; i < sizeof cases / sizeof *cases; i++) {
        fk_model m;
        char error[256] = "";
        EXPECT_FALSE(load(&m, cases[i].rel, error));
        EXPECT_TRUE(strstr(error, cases[i].message) != NULL);
        if (!strstr(error, cases[i].message)) printf("%s: %s\n", cases[i].rel, error);
    }
}

static bool decode(const char *rel, fk_sound *s, const char **why) {
    size_t size;
    void *file = read_fixture(rel, &size);
    bool ok = file && fk_sound_decode(file, size, s, why);
    fk_platform_free(file);
    return ok;
}

UTEST(sound, wav_and_ogg) {
    fk_sound s;
    const char *why = NULL;
    ASSERT_TRUE(decode("sounds/tone.wav", &s, &why)); /* 0.2 s mono at 22050 Hz */
    EXPECT_EQ(s.channels, 1);
    EXPECT_NEAR(s.frames, FK_AUDIO_RATE / 5, 64);
    float peak = 0;
    for (int i = 0; i < s.frames; i++) peak = fmaxf(peak, fabsf(s.samples[i]));
    EXPECT_NEAR(peak, 12000.0f / 32768.0f, 0.02f);
    fk_sound_free(&s);
    ASSERT_TRUE(decode("sounds/tone.ogg", &s, &why)); /* 0.25 s stereo at 44100 Hz */
    EXPECT_EQ(s.channels, 2);
    EXPECT_NEAR(s.frames, FK_AUDIO_RATE / 4, 256);
    fk_sound_free(&s);
}

UTEST(sound, failures) {
    static const struct {
        const char *rel, *message;
    } cases[] = {
        {"sounds/notes.txt", "not a WAV or OGG Vorbis file"},
        {"sounds/broken.ogg", "not a readable OGG Vorbis file"},
        {"sounds/broken.wav", "not a readable WAV file"},
        {"sounds/quad.wav", "only mono and stereo sounds are supported"},
        {"sounds/long.ogg", "longer than 60 seconds (stream music instead)"},
    };
    for (size_t i = 0; i < sizeof cases / sizeof *cases; i++) {
        fk_sound s;
        const char *why = "";
        EXPECT_FALSE(decode(cases[i].rel, &s, &why));
        EXPECT_STREQ(why, cases[i].message);
        EXPECT_TRUE(s.samples == NULL);
    }
}

static int calls;
static void count(void *user) {
    (void)user;
    calls++;
}

UTEST(watch, changes_and_removal) {
    char path[1024];
    snprintf(path, sizeof path, "%s", "test-output/watched.txt");
    fk_platform_make_dir("test-output");
    ASSERT_TRUE(fk_platform_write_file(path, "a", 1));
    calls = 0;
    fk_watch_add(path, count, &calls);
    fk_watch_add("test-output/never-there.txt", count, &calls); /* missing files are skipped */
    EXPECT_EQ(fk_watch_poll(), 0);
    ASSERT_TRUE(fk_platform_write_file(path, "ab", 2)); /* a different size counts even within one clock tick */
    EXPECT_EQ(fk_watch_poll(), 1);
    EXPECT_EQ(calls, 1);
    EXPECT_EQ(fk_watch_poll(), 0);
    for (int i = 0; i < 20; i++) fk_watch_add(path, count, NULL); /* grows past the first allocation */
    fk_watch_remove(&calls);
    fk_watch_remove(NULL);
    ASSERT_TRUE(fk_platform_write_file(path, "abc", 3));
    EXPECT_EQ(fk_watch_poll(), 0);
    fk_watch_clear();
    EXPECT_EQ(calls, 1);
}

/* Hot reload: a texture and a model are loaded again in place when their files change. */
UTEST(watch, reloads_textures_and_models) {
    static const char *files[] = {"textures/checker.png", "models/clip.glb", "models/tri.bin", "models/tri_base.png"};
    char path[1024];
    fk_platform_make_dir("test-output");
    fk_platform_make_dir("test-output/hot");
    fk_platform_make_dir("test-output/hot/data");
    fk_platform_make_dir("test-output/hot/data/textures");
    fk_platform_make_dir("test-output/hot/data/models");
    for (int i = 0; i < 4; i++) { /* copies of the fixtures that the test can change */
        size_t size;
        void *data = read_fixture(files[i], &size);
        snprintf(path, sizeof path, "test-output/hot/data/%s", files[i]);
        ASSERT_TRUE(fk_platform_write_file(path, data, size));
        fk_platform_free(data);
    }
    lua_State *L = fk_script_open(false, 1, false);
    fk_vfs_init("test-output/hot/");
    const char *code = "tex = fk.gfx.texture('textures/checker.png'); model = fk.gfx.model('models/clip.glb')";
    ASSERT_TRUE(fk_script_load(L, code, strlen(code), "=test") && fk_script_call(L, 0, 0));
    size_t size;
    void *jpg = read_fixture("textures/checker.jpg", &size);
    ASSERT_TRUE(fk_platform_write_file("test-output/hot/data/textures/checker.png", jpg, size)); /* any image works */
    fk_platform_free(jpg);
    void *tri = read_fixture("models/tri.gltf", &size);
    fk_vfs_init("test-output/hot/");
    ASSERT_TRUE(fk_platform_write_file("test-output/hot/data/models/clip.glb", tri, size)); /* now a different model */
    fk_platform_free(tri);
    EXPECT_EQ(fk_watch_poll(), 2);
    code = "assert(#model:clips() == 0 and #model:nodes() == 5, 'the model was reloaded')";
    EXPECT_TRUE(fk_script_load(L, code, strlen(code), "=test") && fk_script_call(L, 0, 0));
    ASSERT_TRUE(fk_platform_write_file("test-output/hot/data/models/clip.glb", "broken", 6)); /* a bad file keeps the old one */
    ASSERT_TRUE(fk_platform_write_file("test-output/hot/data/textures/checker.png", "broken", 6));
    EXPECT_EQ(fk_watch_poll(), 2);
    EXPECT_TRUE(fk_script_load(L, code, strlen(code), "=test") && fk_script_call(L, 0, 0));
    fk_script_close(L);
    EXPECT_EQ(fk_watch_poll(), 0); /* closing the scripts forgot their files */
    fk_watch_clear();
}

UTEST(mat4, trs) {
    float m[16], p[3];
    const float t[3] = {1, 2, 3}, q[4] = {0, 0.70710678f, 0, 0.70710678f}, s[3] = {2, 2, 2}; /* 90 degrees about y */
    fk_mat4_trs(m, t, q, s);
    fk_mat4_point(m, (const float[3]){1, 0, 0}, p);
    EXPECT_NEAR(p[0], 1.0f, 1e-5); /* x turns to -z, is doubled and moved */
    EXPECT_NEAR(p[1], 2.0f, 1e-5);
    EXPECT_NEAR(p[2], 1.0f, 1e-5);
}
