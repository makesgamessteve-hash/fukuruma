# Tasks

## 1. Engine (C)

- [x] 1.1 `audio/mixer.c`: voices (2D/3D, loop, pitch, fade, stealing), buses, reverb, limiter, streamed music tracks
- [x] 1.2 SDL3 audio device in `platform.c` (48 kHz stereo float, lock), silent mixing on frame time in `app.c`
- [x] 1.3 `fk.audio` (sounds with hot reload, named variations, voices, listener, buses, reverb, music, fades)

## 2. Game (Lua) and content

- [x] 2.1 `fk/music.lua`, `fk/reverb.lua`, `settings/audio.lua` and the volume rows; menu sounds
- [x] 2.2 `tools/audio/generate.py`, `prompts.json`; generated footsteps, scan, UI sounds, wind, two music themes; CREDITS.md
- [x] 2.3 The sandbox: wind, music by situation, footsteps, the scan, the tower's reverb zone

## 3. Tests

- [x] 3.1 C unit tests: voices, ends, loops, fades, pitch, panning, distance, buses, stealing, limiter, reverb tail, music tracks
- [x] 3.2 Lua tests: `fk.audio` arguments and errors, variations, music crossfades, reverb zones, audio settings, menu rows
- [x] 3.3 `tests/game/audio.lua`

## 4. Verification

- [x] 4.1 Coverage gates, sanitizers, all CTest tests, web build and browser tests
- [ ] 4.2 CI green on every target; Pages updated
- [ ] 4.3 `openspec validate add-audio --strict`; archive after deployment
