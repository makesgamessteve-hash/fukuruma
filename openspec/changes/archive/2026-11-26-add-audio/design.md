# Design

## Context

Sounds decode to 48 kHz float (`add-asset-loading`). Presentation code (feedback bundles, menus, the sandbox) needs
to play them in 3D, loop ambiences and crossfade music, on desktop and in browsers.

## Decisions

### A small C mixer, no audio library
The mixer is ~300 lines of plain C: voices, tracks, buses, reverb and limiter, mixed in blocks of 256 frames with
gains ramped across each block (no zipper noise when sounds move or fade). Plain C keeps it testable offline (the
unit tests mix into arrays) and identical on every platform; SDL only delivers the buffers.

### Threads
SDL3 calls the audio callback with the stream lock held. Every `fk.audio` call takes the same lock
(`fk_platform_audio_lock`) around mixer changes. In the browser the callback runs on the main thread, and the lock is
a no-op without a device.

### Silent runs mix on frame time
Scenarios, `--no-render` runs and machines without a device advance the mixer by the frame time into a scratch
buffer. Voices end exactly as they would audibly, so tests can check them, and runs stay reproducible.

### 3D sound
Inverse-distance attenuation (full within 2 m), fading out between 90 and 120 m; equal-power panning by the angle
to the listener's right vector (from the camera). Sounds are mono for 3D; stereo files keep their channels.

### Variations and voice stealing
`fk.audio.play("footstep")` loads `sounds/footstep.ogg`, or `footstep_1.ogg` … `footstep_9.ogg`, once, and picks one
at random with ±4% pitch from presentation's own random stream. When all 48 voices play, the quietest one-shot is
replaced; loops are never stolen. A voice keeps its sound alive (a registry table) until it ends.

### Music tracks stream
Music files stay compressed in memory and are decoded with stb_vorbis while they play (90 s of stereo float would be
35 MB). Silent tracks pause. `fk/music.lua` loads every track at volume 0 and crossfades by situation; a name used
again replaces its track (restarts, hot reload).

### Reverb zones
`fk/reverb.lua` holds spheres with room size, damping and wet level and applies the smallest one around the listener
(or the default); the mixer glides to new values over 0.2 s. Effects send fully, ambience half, UI and music not.

### Generated content
`generate.py` hashes each prompt entry and only calls ElevenLabs for new or changed ones (`generated.json`), so the
repository's sounds stay stable and reruns cost nothing. Output is requested as 48 kHz WAV (sound effects) or 48 kHz
MP3 (music), loudness-normalised (-18 LUFS) and stored as OGG Vorbis (effects mono, music stereo). The key is read
from `ELEVENLABS_API_KEY`; in the cloud environment a network secret supplies it.

### Licence
The generated audio is published under CC BY 4.0 like the other assets, subject to the owner's ElevenLabs plan
allowing it; `CREDITS.md` records model, date and prompt for every file.

## Risks / Trade-offs

- The mixer runs on the audio thread's budget: 48 voices with linear interpolation, two Vorbis streams and the reverb
  are well below 5% of a core.
- Music themes crossfade rather than layer in sync; generating matching stems is not reliable yet.
