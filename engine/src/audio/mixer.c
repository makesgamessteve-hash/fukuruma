#include "audio/mixer.h"

#include <math.h>
#include <stdio.h>
#include <string.h>

#include "platform/platform.h"

#define STB_VORBIS_HEADER_ONLY
#define STB_VORBIS_NO_STDIO
#define STB_VORBIS_NO_PUSHDATA_API
#include "stb_vorbis.c"

#define BLOCK 256           /* frames mixed with one gain ramp */
#define REF_DISTANCE 2.0f   /* full volume within this many metres */
#define MAX_DISTANCE 120.0f /* silent beyond, fading out over the last quarter */
#define QUARTER_PI 0.78539816f

typedef struct {
    int id; /* 0: free */
    fk_voice_params p;
    double pos;    /* frames into the sound */
    float gain[2]; /* applied at the end of the last block */
    float fade, fade_left;
} voice;

typedef struct {
    char name[32];
    void *ogg;
    stb_vorbis *v;
    float gain, target, rate;
} track;

static voice voices[FK_MAX_VOICES];
static track tracks[FK_MAX_TRACKS];
static int next_id = 1;
static float bus_volume[FK_BUS_COUNT], master;
static const float bus_send[FK_BUS_COUNT] = {1.0f, 0.0f, 0.5f, 0.0f}; /* reverb send: effects and ambience */
static float listener_pos[3], listener_right[3];

/* Reverb: Freeverb-style, four damped combs and two all-passes per channel (delays scaled to 48 kHz). */
static const int COMB[4] = {1760, 1694, 1623, 1548}, ALLPASS[2] = {605, 480}, SPREAD = 25;
static float comb_buf[2][4][1800], comb_store[2][4], allpass_buf[2][2][640];
static int comb_at[2][4], allpass_at[2][2];
static float room, damping, wet, room_target, damping_target, wet_target;

void fk_mixer_reset(void) {
    for (int i = 0; i < FK_MAX_TRACKS; i++) {
        if (tracks[i].v) stb_vorbis_close(tracks[i].v);
        fk_platform_free(tracks[i].ogg);
    }
    memset(voices, 0, sizeof voices);
    memset(tracks, 0, sizeof tracks);
    memset(comb_buf, 0, sizeof comb_buf);
    memset(comb_store, 0, sizeof comb_store);
    memset(allpass_buf, 0, sizeof allpass_buf);
    memset(comb_at, 0, sizeof comb_at);
    memset(allpass_at, 0, sizeof allpass_at);
    for (int b = 0; b < FK_BUS_COUNT; b++) bus_volume[b] = 1;
    master = 1;
    memset(listener_pos, 0, sizeof listener_pos);
    listener_right[0] = 1, listener_right[1] = listener_right[2] = 0;
    room = room_target = 0.5f, damping = damping_target = 0.5f, wet = wet_target = 0.15f;
}

static voice *find(int id) {
    for (int i = 0; i < FK_MAX_VOICES; i++)
        if (id && voices[i].id == id) return &voices[i];
    return NULL;
}

int fk_mixer_play(const fk_voice_params *p) {
    voice *v = NULL;
    for (int i = 0; !v && i < FK_MAX_VOICES; i++)
        if (!voices[i].id) v = &voices[i];
    for (int i = 0; !v && i < FK_MAX_VOICES; i++) /* all busy: the quietest one-shot makes room */
        if (!voices[i].p.loop && (!v || voices[i].gain[0] + voices[i].gain[1] < v->gain[0] + v->gain[1])) v = &voices[i];
    if (!v) return 0; /* only loops playing: the new sound is dropped */
    memset(v, 0, sizeof *v);
    v->id = next_id++;
    v->p = *p;
    return v->id;
}

bool fk_mixer_alive(int id) { return find(id) != NULL; }

void fk_mixer_stop(int id, float fade_seconds) {
    voice *v = find(id);
    if (!v) return;
    if (fade_seconds <= 0) v->id = 0;
    else if (v->fade == 0 || fade_seconds < v->fade_left) v->fade = v->fade_left = fade_seconds;
}

void fk_mixer_set(int id, const float *volume, const float *pitch, const float position[3]) {
    voice *v = find(id);
    if (!v) return;
    if (volume) v->p.volume = *volume;
    if (pitch) v->p.pitch = *pitch;
    if (position) memcpy(v->p.position, position, sizeof v->p.position);
}

void fk_mixer_stop_sound(const fk_sound *s) {
    for (int i = 0; i < FK_MAX_VOICES; i++)
        if (voices[i].p.sound == s) voices[i].id = 0;
}

int fk_mixer_active(void) {
    int n = 0;
    for (int i = 0; i < FK_MAX_VOICES; i++) n += voices[i].id != 0;
    return n;
}

void fk_mixer_listener(const float position[3], const float right[3]) {
    float len = sqrtf(right[0] * right[0] + right[1] * right[1] + right[2] * right[2]);
    memcpy(listener_pos, position, sizeof listener_pos);
    for (int k = 0; k < 3; k++) listener_right[k] = len > 0 ? right[k] / len : (k == 0);
}

void fk_mixer_volume(int bus, float volume) {
    if (bus < 0) master = volume;
    else if (bus < FK_BUS_COUNT) bus_volume[bus] = volume;
}

void fk_mixer_reverb(float r, float d, float w) { room_target = r, damping_target = d, wet_target = w; }

static track *find_track(const char *name) {
    for (int i = 0; i < FK_MAX_TRACKS; i++)
        if (tracks[i].v && strcmp(tracks[i].name, name) == 0) return &tracks[i];
    return NULL;
}

bool fk_mixer_track(const char *name, void *ogg, size_t size, float volume, const char **error) {
    int err = 0;
    *error = NULL;
    stb_vorbis *v = size <= 0x7fffffff ? stb_vorbis_open_memory(ogg, (int)size, &err, NULL) : NULL;
    stb_vorbis_info info = v ? stb_vorbis_get_info(v) : (stb_vorbis_info){0};
    if (!v || info.channels < 1 || info.channels > 2) *error = "not a readable OGG Vorbis file (mono or stereo)";
    else if (info.sample_rate != 48000) *error = "music must be 48 kHz";
    track *t = v && !*error ? find_track(name) : NULL; /* the same name again replaces the track */
    if (t) {
        stb_vorbis_close(t->v);
        fk_platform_free(t->ogg);
        t->v = NULL;
    }
    for (int i = 0; v && !*error && i < FK_MAX_TRACKS && !t; i++)
        if (!tracks[i].v) t = &tracks[i];
    if (v && !*error && !t) *error = "too many music tracks (at most 4)";
    if (*error) {
        if (v) stb_vorbis_close(v);
        fk_platform_free(ogg);
        return false;
    }
    snprintf(t->name, sizeof t->name, "%s", name);
    t->ogg = ogg, t->v = v;
    t->gain = t->target = volume, t->rate = 0;
    return true;
}

bool fk_mixer_fade(const char *name, float volume, float seconds) {
    track *t = find_track(name);
    if (!t) return false;
    t->target = volume;
    if (seconds <= 0) t->gain = volume, t->rate = 0;
    else t->rate = fabsf(volume - t->gain) / seconds;
    return true;
}

float fk_mixer_track_volume(const char *name) {
    const track *t = find_track(name);
    return t ? t->gain : -1;
}

static void target_gains(const voice *v, float g[2]) {
    float base = v->p.volume * bus_volume[v->p.bus] * master, pan = v->p.pan;
    if (v->p.spatial) {
        float d[3], dist = 0;
        for (int k = 0; k < 3; k++) d[k] = v->p.position[k] - listener_pos[k], dist += d[k] * d[k];
        dist = sqrtf(dist);
        base *= dist <= REF_DISTANCE ? 1.0f : REF_DISTANCE / dist; /* inverse distance */
        if (dist > 0.75f * MAX_DISTANCE) base *= fmaxf(0.0f, (MAX_DISTANCE - dist) / (0.25f * MAX_DISTANCE));
        pan = dist > 1e-4f ? (d[0] * listener_right[0] + d[1] * listener_right[1] + d[2] * listener_right[2]) / dist : 0;
    }
    if (v->fade > 0) base *= v->fade_left / v->fade;
    float a = (pan + 1) * QUARTER_PI; /* equal power: -3 dB per side in the centre */
    g[0] = base * cosf(a), g[1] = base * sinf(a);
}

static void mix_voice(voice *v, float *out, float *send, int n) {
    float g1[2];
    target_gains(v, g1);
    const fk_sound *s = v->p.sound;
    int ch = s->channels, frames = s->frames;
    float sendk = bus_send[v->p.bus];
    for (int i = 0; i < n; i++) {
        float t = (float)(i + 1) / (float)n, gl = v->gain[0] + (g1[0] - v->gain[0]) * t, gr = v->gain[1] + (g1[1] - v->gain[1]) * t;
        int i0 = (int)v->pos, i1 = i0 + 1;
        float frac = (float)(v->pos - i0);
        if (i1 >= frames) i1 = v->p.loop ? 0 : i0;
        float l = s->samples[i0 * ch] + (s->samples[i1 * ch] - s->samples[i0 * ch]) * frac;
        float r = ch == 2 ? s->samples[i0 * 2 + 1] + (s->samples[i1 * 2 + 1] - s->samples[i0 * 2 + 1]) * frac : l;
        out[i * 2] += l * gl, out[i * 2 + 1] += r * gr;
        send[i * 2] += l * gl * sendk, send[i * 2 + 1] += r * gr * sendk;
        v->pos += v->p.pitch;
        if (v->pos >= frames) {
            if (!v->p.loop) {
                v->id = 0;
                return;
            }
            v->pos -= frames;
        }
    }
    v->gain[0] = g1[0], v->gain[1] = g1[1];
    if (v->fade > 0) {
        v->fade_left -= (float)n / FK_AUDIO_RATE;
        if (v->fade_left <= 0) v->id = 0;
    }
}

static void mix_track(track *t, float *out, int n) {
    if (t->gain <= 0 && t->target <= 0) return; /* silent tracks pause where they are */
    float buf[BLOCK * 2];
    int got = 0, rewinds = 0;
    while (got < n && rewinds < 2) {
        int k = stb_vorbis_get_samples_float_interleaved(t->v, 2, buf + got * 2, (n - got) * 2);
        if (k > 0) got += k, rewinds = 0;
        else stb_vorbis_seek_start(t->v), rewinds++; /* the end: loop (twice in a row means an empty file) */
    }
    float step = t->rate / FK_AUDIO_RATE, scale = bus_volume[FK_BUS_MUSIC] * master;
    for (int i = 0; i < got; i++) {
        if (t->gain < t->target) t->gain = fminf(t->target, t->gain + step);
        else if (t->gain > t->target) t->gain = fmaxf(t->target, t->gain - step);
        out[i * 2] += buf[i * 2] * t->gain * scale, out[i * 2 + 1] += buf[i * 2 + 1] * t->gain * scale;
    }
}

static void reverb(const float *send, float *out, int n) {
    float glide = (float)n / (0.2f * FK_AUDIO_RATE);
    room += (room_target - room) * fminf(1, glide), damping += (damping_target - damping) * fminf(1, glide);
    wet += (wet_target - wet) * fminf(1, glide);
    float feedback = 0.7f + room * 0.28f, damp = damping * 0.4f;
    for (int i = 0; i < n; i++) {
        float in = (send[i * 2] + send[i * 2 + 1]) * 0.015f;
        for (int c = 0; c < 2; c++) {
            float acc = 0;
            for (int k = 0; k < 4; k++) {
                int len = COMB[k] + c * SPREAD;
                float *buf = comb_buf[c][k], o = buf[comb_at[c][k]];
                comb_store[c][k] = o * (1 - damp) + comb_store[c][k] * damp;
                buf[comb_at[c][k]] = in + comb_store[c][k] * feedback;
                if (++comb_at[c][k] >= len) comb_at[c][k] = 0;
                acc += o;
            }
            for (int k = 0; k < 2; k++) {
                int len = ALLPASS[k] + c * SPREAD;
                float *buf = allpass_buf[c][k], b = buf[allpass_at[c][k]];
                buf[allpass_at[c][k]] = acc + b * 0.5f;
                acc = b - acc;
                if (++allpass_at[c][k] >= len) allpass_at[c][k] = 0;
            }
            out[i * 2 + c] += acc * wet * 3.0f;
        }
    }
}

static float soft_clip(float x) { /* untouched below 0.9, then bends smoothly towards 1 */
    float a = fabsf(x);
    if (a <= 0.9f) return x;
    return copysignf(0.9f + 0.1f * tanhf((a - 0.9f) / 0.1f), x);
}

void fk_mixer_mix(float *out, int frames) {
    static float send[BLOCK * 2];
    memset(out, 0, (size_t)frames * 2 * sizeof(float));
    for (int start = 0; start < frames; start += BLOCK) {
        int n = frames - start < BLOCK ? frames - start : BLOCK;
        float *o = out + start * 2;
        memset(send, 0, sizeof send);
        for (int i = 0; i < FK_MAX_VOICES; i++)
            if (voices[i].id) mix_voice(&voices[i], o, send, n);
        for (int i = 0; i < FK_MAX_TRACKS; i++)
            if (tracks[i].v) mix_track(&tracks[i], o, n);
        reverb(send, o, n);
        for (int i = 0; i < n * 2; i++) o[i] = soft_clip(o[i]);
    }
}
