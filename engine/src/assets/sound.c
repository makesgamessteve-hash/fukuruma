#include "assets/sound.h"

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "platform/platform.h"

#define STB_VORBIS_HEADER_ONLY
#define STB_VORBIS_NO_STDIO
#define STB_VORBIS_NO_PUSHDATA_API
#include "stb_vorbis.c"

static bool fail(fk_sound *out, const char **error, const char *why) {
    memset(out, 0, sizeof *out);
    *error = why;
    return false;
}

/* Takes an interleaved float buffer at rate (allocated with free_fn) and stores it in out at FK_AUDIO_RATE. */
static bool finish(fk_sound *out, float *pcm, void (*free_fn)(void *), int frames, int channels, int rate, const char **error) {
    if (channels < 1 || channels > 2) {
        free_fn(pcm);
        return fail(out, error, "only mono and stereo sounds are supported");
    }
    if (frames > FK_MAX_SOUND_SECONDS * rate) {
        free_fn(pcm);
        return fail(out, error, "longer than 60 seconds (stream music instead)");
    }
    float *res = pcm;
    if (rate != FK_AUDIO_RATE) {
        res = fk_platform_resample(pcm, frames, channels, rate, FK_AUDIO_RATE, &frames);
        free_fn(pcm);
        if (!res) return fail(out, error, "the sample rate cannot be converted");
        free_fn = fk_platform_free;
    }
    out->samples = malloc((size_t)frames * (size_t)channels * sizeof(float) + 1);
    if (out->samples) memcpy(out->samples, res, (size_t)frames * (size_t)channels * sizeof(float));
    free_fn(res);
    if (!out->samples) return fail(out, error, "out of memory");
    out->frames = frames;
    out->channels = channels;
    return true;
}

bool fk_sound_decode(const void *data, size_t size, fk_sound *out, const char **error) {
    const char *b = data;
    if (size >= 4 && memcmp(b, "OggS", 4) == 0) {
        int err = 0;
        stb_vorbis *v = size <= INT_MAX ? stb_vorbis_open_memory((const unsigned char *)data, (int)size, &err, NULL) : NULL;
        if (!v) return fail(out, error, "not a readable OGG Vorbis file");
        stb_vorbis_info info = stb_vorbis_get_info(v);
        unsigned total = stb_vorbis_stream_length_in_samples(v);
        if (info.channels < 1 || info.channels > 2 || total == 0 || total > FK_MAX_SOUND_SECONDS * info.sample_rate) {
            stb_vorbis_close(v);
            return fail(out, error, total == 0 ? "not a readable OGG Vorbis file"
                                    : info.channels < 1 || info.channels > 2 ? "only mono and stereo sounds are supported"
                                                                              : "longer than 60 seconds (stream music instead)");
        }
        float *f = malloc((size_t)total * (size_t)info.channels * sizeof(float));
        int frames = f ? stb_vorbis_get_samples_float_interleaved(v, info.channels, f, (int)(total * (unsigned)info.channels)) : 0;
        stb_vorbis_close(v);
        if (!f) return fail(out, error, "out of memory");
        return finish(out, f, free, frames, info.channels, (int)info.sample_rate, error);
    }
    if (size >= 12 && memcmp(b, "RIFF", 4) == 0 && memcmp(b + 8, "WAVE", 4) == 0) {
        int channels = 0, frames = 0;
        float *pcm = fk_platform_wav(data, size, FK_AUDIO_RATE, &channels, &frames);
        if (!pcm) return fail(out, error, "not a readable WAV file");
        return finish(out, pcm, fk_platform_free, frames, channels, FK_AUDIO_RATE, error);
    }
    return fail(out, error, "not a WAV or OGG Vorbis file");
}

void fk_sound_free(fk_sound *s) {
    free(s->samples);
    memset(s, 0, sizeof *s);
}
