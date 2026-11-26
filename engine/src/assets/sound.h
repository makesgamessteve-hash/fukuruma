/* Decodes WAV and OGG Vorbis files to float samples at the mixer's rate. */
#pragma once
#include <stdbool.h>
#include <stddef.h>

#define FK_AUDIO_RATE 48000
#define FK_MAX_SOUND_SECONDS 60 /* longer audio (music) is streamed, not decoded at once */

typedef struct {
    float *samples; /* interleaved, frames x channels, at FK_AUDIO_RATE */
    int frames, channels; /* channels: 1 or 2 */
} fk_sound;

/* On failure returns false with a reason in *error. */
bool fk_sound_decode(const void *data, size_t size, fk_sound *out, const char **error);
void fk_sound_free(fk_sound *s);
