# Proposal

## Why

M1 must be playable "with sound" (`docs/IMPLEMENTATION_PLAN.md`, M1 exit), and the owner asked for epic sound
effects and ambient space music generated with the ElevenLabs API. The feedback bundles of `add-game-feel`
already name their sounds; nothing plays them yet.

## What Changes

- **A mixer** in C: up to 48 voices of decoded sounds (2D with pan, or 3D with distance attenuation and
  equal-power panning to a listener), looping, pitch, fades, quietest-voice stealing; buses for effects, UI,
  ambience and music with a master volume; a reverb send (Freeverb-style) whose room, damping and wet level glide;
  a soft limiter. Music tracks stream from OGG Vorbis (48 kHz), loop and crossfade by name.
- **Sound device:** SDL3 audio at 48 kHz stereo float, opened only for interactive play; test runs mix silently on
  frame time, so they stay reproducible and voices still start and end on time.
- **`fk.audio`:** `sound`, `play` (a sound or a name with variations `name_1.ogg`, `name_2.ogg`, … picked at random
  with a little pitch variation), `stop`, `set`, `alive`, `active`, `listener`, `volume`, `reverb`, `music`, `fade`,
  `track_volume`. Sounds reload in place on desktop debug builds.
- **Lua:** `fk/music.lua` (situations crossfade tracks), `fk/reverb.lua` (reverb zones), `settings/audio.lua`
  (music and effects volumes in the settings menu), menu sounds (move, confirm, open).
- **`tools/audio/generate.py`** with `tools/audio/prompts.json`: calls ElevenLabs only for changed prompts,
  converts to OGG Vorbis at 48 kHz with ffmpeg, records provenance in `data/sounds/CREDITS.md` and
  `data/music/CREDITS.md`. The key comes from the environment.
- **The first sounds:** three Exosuit footsteps, the scan pulse, three UI sounds, a wind ambience loop, and two music
  themes (surface, discovery). The sandbox plays them: wind and the surface theme, footsteps, the scan with a swell
  of the discovery theme, and a ringing reverb near the beacon tower.

**Out of scope:** occlusion and Doppler, HRTF, voice chat, music stems that play in sync (tracks crossfade).

**Proving game test:** `tests/game/audio.lua` checks the sandbox's wind and music, footsteps that start and end on
time, the scan's crossfade to the discovery theme, and the tower's reverb zone.

## Capabilities

### New Capabilities
- `audio`: mixer, 3D sound, buses, reverb zones, music tracks, the ElevenLabs tool, the first sounds.

## Impact

New `engine/src/audio/mixer.{h,c}`, `engine/src/script/lua_audio.c`, audio device functions in `platform.c`,
`data/scripts/fk/{music,reverb}.lua`, `data/scripts/settings/audio.lua`, `tools/audio/`, `data/sounds/`,
`data/music/` (about 2 MB more in the web package).
