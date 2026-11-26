/* The audio mixer: voices of decoded sounds (2D or 3D), streamed music tracks, buses, a reverb send and a
   soft limiter, mixed to 48 kHz stereo float. Plain C; the platform's audio callback calls fk_mixer_mix while
   holding the audio lock, and every other function must be called with that lock held too. */
#pragma once
#include <stdbool.h>
#include <stddef.h>

#include "assets/sound.h"

#define FK_MAX_VOICES 48
#define FK_MAX_TRACKS 4

enum { FK_BUS_SFX, FK_BUS_UI, FK_BUS_AMBIENT, FK_BUS_MUSIC, FK_BUS_COUNT };

typedef struct {
    const fk_sound *sound;
    float volume, pitch, pan; /* volume 0..4, pitch (playback rate) 0.25..4, pan -1..1 (2D voices) */
    bool loop, spatial;
    float position[3];        /* spatial voices: metres in the world */
    int bus;
} fk_voice_params;

void fk_mixer_reset(void); /* silence: no voices, no tracks, default volumes and reverb */
/* Starts a voice and returns its id (never 0); when all voices are busy, the quietest one-shot voice makes room. */
int fk_mixer_play(const fk_voice_params *p);
bool fk_mixer_alive(int id);
void fk_mixer_stop(int id, float fade_seconds);
void fk_mixer_set(int id, const float *volume, const float *pitch, const float position[3]); /* NULL: unchanged */
void fk_mixer_stop_sound(const fk_sound *s); /* stops the voices that play s at once (before freeing it) */
int fk_mixer_active(void);                    /* voices playing */
void fk_mixer_listener(const float position[3], const float right[3]);
void fk_mixer_volume(int bus, float volume);  /* bus -1: master */
void fk_mixer_reverb(float room, float damping, float wet); /* 0..1 each; changes glide over 0.2 s */
/* Music tracks: an OGG Vorbis file (taken over, freed with fk_platform_free) that loops, faded by name. A name used
   again replaces its track. */
bool fk_mixer_track(const char *name, void *ogg, size_t size, float volume, const char **error);
bool fk_mixer_fade(const char *name, float volume, float seconds);
float fk_mixer_track_volume(const char *name); /* -1 when there is no such track */
/* Mixes frames of 48 kHz stereo into out (interleaved). */
void fk_mixer_mix(float *out, int frames);
