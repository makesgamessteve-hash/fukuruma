# Spec Delta

## Purpose

Plays the game's sounds and music: 2D and 3D voices, buses with volumes, reverb zones and crossfading music tracks,
from sounds generated with the ElevenLabs tool. Audio is presentation and never changes the simulation.

## ADDED Requirements

### Requirement: Voices
Scripts SHALL play sounds once or looping, in 2D with a pan or in 3D at a position, with a volume and a pitch, change
playing voices, and stop them at once or with a fade. When every voice is busy, the quietest one-shot voice SHALL make
room; loops SHALL keep playing.

#### Scenario: A footstep to the right
- **WHEN** a footstep plays 10 m to the right of the listener
- **THEN** it is heard on the right only, at a fifth of its volume at 2 m

#### Scenario: Voices end on time
- **WHEN** a 0.9 s footstep plays during a test run
- **THEN** it is no longer active a second later

### Requirement: Named sounds with variations
Playing a sound by name SHALL use `sounds/<name>.ogg`, or pick at random one of `sounds/<name>_1.ogg`,
`<name>_2.ogg`, … with a slight random pitch, so repeated sounds do not sound mechanical.

#### Scenario: Footsteps vary
- **WHEN** the Exosuit walks
- **THEN** its footsteps use the three footstep variations

### Requirement: Buses and settings
Sounds SHALL play on the effects, UI or ambience bus and music on the music bus, each with a volume, under a master
volume. The settings menu SHALL offer music and effects volumes (100%, 75%, 50%, 25%, off) and store them.

#### Scenario: Music off
- **WHEN** the player sets the music volume to off
- **THEN** no music is heard and the effects keep their volume

### Requirement: Music tracks
Looping music tracks SHALL stream from 48 kHz OGG Vorbis files and crossfade by name over a given time; the game
SHALL pick the track by situation.

#### Scenario: Discovery swell
- **WHEN** the player scans in the sandbox
- **THEN** the discovery theme fades in and the surface theme out within about two seconds, and the surface theme
  returns later

### Requirement: Reverb zones
The listener SHALL hear the reverb of the smallest zone around it (room size, damping, wet level), or the default
outside every zone, gliding between settings.

#### Scenario: The beacon tower
- **WHEN** the Exosuit walks up to the beacon tower
- **THEN** its sounds ring with the tower's long reverb

### Requirement: Generated sounds
`tools/audio/generate.py` SHALL generate the sound effects and music listed in `tools/audio/prompts.json` with the
ElevenLabs API, only for new or changed entries, convert them to OGG Vorbis at 48 kHz, and record each file's model,
date and prompt in the folder's `CREDITS.md`. It SHALL read the API key from the environment and never store it.

#### Scenario: Unchanged prompts
- **WHEN** the tool runs again without changes to the prompts
- **THEN** it calls no API and changes no file

### Requirement: Silent test runs
Test runs and machines without a sound device SHALL mix on frame time without output, so voices and fades behave as
when heard and runs stay reproducible.

#### Scenario: Scenario timing
- **WHEN** a scenario runs for 60 frames
- **THEN** one second of audio has been mixed
