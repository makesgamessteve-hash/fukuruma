#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "assets/vfs.h"
#include "audio/mixer.h"
#include "platform/platform.h"
#include "utest.h"

static float dc[48000]; /* one second of a constant 0.5 */
static fk_sound dc_sound = {dc, 48000, 1};

static void setup(void) {
    for (int i = 0; i < 48000; i++) dc[i] = 0.5f;
    fk_mixer_reset();
    fk_mixer_reverb(0.5f, 0.5f, 0.0f);
    static float silence[96000 * 2];
    fk_mixer_mix(silence, 96000); /* two seconds: the reverb has glided to dry */
}

static fk_voice_params params(void) {
    fk_voice_params p = {&dc_sound, 1, 1, 0, false, false, {0, 0, 0}, FK_BUS_SFX};
    return p;
}

/* Mixes frames and returns the last frame's left and right samples. */
static void mix(int frames, float *l, float *r) {
    float *out = malloc((size_t)frames * 2 * sizeof(float));
    fk_mixer_mix(out, frames);
    *l = out[frames * 2 - 2], *r = out[frames * 2 - 1];
    free(out);
}

UTEST(mixer, voices_play_end_and_loop) {
    setup();
    fk_voice_params p = params();
    int id = fk_mixer_play(&p);
    EXPECT_NE(id, 0);
    float l, r;
    mix(24000, &l, &r);
    EXPECT_NEAR(l, 0.5f * 0.70710678f, 0.01f); /* centred: -3 dB per side */
    EXPECT_NEAR(r, l, 1e-5);
    mix(24001, &l, &r);
    EXPECT_FALSE(fk_mixer_alive(id)); /* one second of sound has played */
    EXPECT_EQ(fk_mixer_active(), 0);
    p.loop = true;
    p.pitch = 2;
    id = fk_mixer_play(&p);
    mix(48000 * 3, &l, &r);
    EXPECT_TRUE(fk_mixer_alive(id)); /* loops keep playing */
    fk_mixer_stop(id, 0.5f);
    fk_mixer_stop(id, 1.0f); /* a slower fade does not extend the first */
    mix(12000, &l, &r);
    EXPECT_TRUE(fk_mixer_alive(id));
    EXPECT_LT(l, 0.5f * 0.70710678f);
    mix(14000, &l, &r);
    EXPECT_FALSE(fk_mixer_alive(id));
    fk_mixer_stop(id, 0); /* stopping a finished voice does nothing */
    p.loop = false;
    p.pitch = 2; /* twice as fast: done in half a second */
    id = fk_mixer_play(&p);
    mix(24100, &l, &r);
    EXPECT_FALSE(fk_mixer_alive(id));
}

UTEST(mixer, panning_distance_and_buses) {
    setup();
    fk_voice_params p = params();
    p.pan = 1;
    int id = fk_mixer_play(&p);
    float l, r;
    mix(4096, &l, &r);
    EXPECT_NEAR(l, 0.0f, 1e-5);
    EXPECT_NEAR(r, 0.5f, 1e-3); /* hard right */
    fk_mixer_stop(id, 0);
    p.pan = 0;
    p.spatial = true;
    p.position[0] = 10;
    fk_mixer_listener((float[3]){0, 0, 0}, (float[3]){2, 0, 0});
    id = fk_mixer_play(&p);
    mix(4096, &l, &r);
    EXPECT_NEAR(r, 0.5f * 0.2f, 1e-3); /* to the right, 10 m away: 2 m / 10 m */
    EXPECT_NEAR(l, 0.0f, 1e-5);
    fk_mixer_set(id, NULL, NULL, (float[3]){0, 0, -1}); /* in front, within the reference distance */
    mix(4096, &l, &r);
    EXPECT_NEAR(l, 0.5f * 0.70710678f, 1e-3);
    fk_mixer_set(id, NULL, NULL, (float[3]){100, 0, 0}); /* near the far limit: fading out */
    mix(4096, &l, &r);
    EXPECT_LT(r, 0.5f * 0.02f);
    fk_mixer_set(id, NULL, NULL, (float[3]){200, 0, 0});
    mix(4096, &l, &r);
    EXPECT_NEAR(r, 0.0f, 1e-6);
    float half = 0.5f, fast = 1.5f;
    fk_mixer_set(id, &half, &fast, (float[3]){0, 0, 0});
    fk_mixer_volume(FK_BUS_SFX, 0.5f);
    fk_mixer_volume(-1, 2.0f);
    mix(4096, &l, &r);
    EXPECT_NEAR(l, 0.5f * 0.5f * 0.5f * 2.0f * 0.70710678f, 2e-3); /* voice, bus and master volumes */
    fk_mixer_volume(FK_BUS_SFX, 0);
    mix(4096, &l, &r);
    EXPECT_NEAR(l, 0.0f, 1e-6);
    fk_mixer_volume(99, 1); /* unknown buses are ignored */
    fk_mixer_listener((float[3]){0, 0, 0}, (float[3]){0, 0, 0}); /* no right vector: +x */
    fk_mixer_set(9999, &half, NULL, NULL); /* unknown voices are ignored */
}

UTEST(mixer, stealing_limiter_reverb_and_stop_sound) {
    setup();
    fk_voice_params p = params();
    for (int i = 0; i < FK_MAX_VOICES; i++) EXPECT_NE(fk_mixer_play(&p), 0);
    EXPECT_NE(fk_mixer_play(&p), 0); /* a one-shot makes room */
    EXPECT_EQ(fk_mixer_active(), FK_MAX_VOICES);
    p.volume = 4; /* 48 loud voices: far beyond full scale */
    setup();
    for (int i = 0; i < 8; i++) fk_mixer_play(&p);
    float l, r;
    mix(4096, &l, &r);
    EXPECT_LE(l, 1.0f); /* the limiter keeps it within full scale */
    EXPECT_GT(l, 0.9f);
    fk_mixer_stop_sound(&dc_sound);
    EXPECT_EQ(fk_mixer_active(), 0);
    p.loop = true;
    for (int i = 0; i < FK_MAX_VOICES; i++) fk_mixer_play(&p);
    EXPECT_EQ(fk_mixer_play(&p), 0); /* only loops: nothing to steal */
    fk_mixer_reset();
    fk_mixer_reverb(0.9f, 0.2f, 1.0f);
    p = params();
    fk_mixer_play(&p);
    mix(48000, &l, &r);
    mix(4800, &l, &r); /* the sound ended 0.1 s ago */
    EXPECT_GT(fabsf(l) + fabsf(r), 1e-4f); /* the room still rings */
}

static void *fixture(const char *rel, size_t *size) {
    fk_vfs_init(FK_TESTS_DIR "/fixtures/assets/");
    return fk_vfs_read(rel, size);
}

/* Reads the fixture first: arguments are evaluated in no fixed order, so size must be set before the call. */
static bool track(const char *name, const char *rel, float volume, const char **why) {
    size_t size;
    void *ogg = fixture(rel, &size);
    return fk_mixer_track(name, ogg, size, volume, why);
}

UTEST(mixer, music_tracks) {
    setup();
    const char *why = NULL;
    EXPECT_FALSE(track("x", "sounds/tone.ogg", 1, &why));
    EXPECT_STREQ(why, "music must be 48 kHz");
    EXPECT_FALSE(track("x", "sounds/broken.ogg", 1, &why));
    EXPECT_STREQ(why, "not a readable OGG Vorbis file (mono or stereo)");
    ASSERT_TRUE(track("calm", "sounds/music48.ogg", 0, &why));
    ASSERT_TRUE(track("calm", "sounds/music48.ogg", 0, &why)); /* replaced */
    for (int i = 0; i < 3; i++) {
        char name[8] = {'t', (char)('0' + i), 0};
        ASSERT_TRUE(track(name, "sounds/music48.ogg", 0, &why));
    }
    EXPECT_FALSE(track("fifth", "sounds/music48.ogg", 0, &why));
    EXPECT_STREQ(why, "too many music tracks (at most 4)");
    float l, r;
    mix(4800, &l, &r);
    EXPECT_EQ(fk_mixer_track_volume("calm"), 0.0f);
    EXPECT_TRUE(fk_mixer_fade("calm", 1, 0.5f));
    mix(12000, &l, &r);
    EXPECT_NEAR(fk_mixer_track_volume("calm"), 0.5f, 0.01f); /* halfway through the fade */
    mix(48000, &l, &r);                                       /* the 0.2 s track loops */
    EXPECT_EQ(fk_mixer_track_volume("calm"), 1.0f);
    EXPECT_GT(fabsf(l) + fabsf(r), 0.0f);
    EXPECT_TRUE(fk_mixer_fade("calm", 0.2f, 0));
    EXPECT_NEAR(fk_mixer_track_volume("calm"), 0.2f, 1e-6);
    EXPECT_TRUE(fk_mixer_fade("calm", 0, 0.1f));
    mix(48000, &l, &r);
    EXPECT_FALSE(fk_mixer_fade("nothing", 1, 1));
    EXPECT_EQ(fk_mixer_track_volume("nothing"), -1.0f);
    fk_mixer_reset();
}
