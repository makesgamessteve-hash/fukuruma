# Proposal

## Why

Plan M14 (Release 1.0) asks for a performance pass on the target devices, save compatibility tests, release
packaging and a press kit page on Pages.

## What Changes

- **Save compatibility.**
  - The save format of release 1.0 is version 2. Saves from earlier development versions are refused with a clear
    message.
  - `tests/lua/save_compat_test.lua` holds a real 1.0 save and checks that it loads and plays on. Any later change
    that breaks it needs a migration in `save.MIGRATIONS`.
- **Release packaging.**
  - Release presets for Linux, Windows and macOS.
  - `.github/workflows/release.yml`: a tag `v*` builds each platform in Release, runs the unit tests, zips the
    executable with `data/`, `mods/`, the licences and the notices, and attaches the zips to the tag's GitHub Release.
- **Press kit.** `web/presskit.html`, published on Pages next to the game with six screenshots from the game's golden
  images: what the game is, facts, features, screenshots and where to get it.
- **Not included.** The performance pass on target devices (phones, Quest-class headsets) needs those devices. The
  quality presets and the browser suite's timings stand in for it until then.

## Capabilities

### New Capabilities
- `release`: save compatibility, packaging, the press kit.

## Impact

- New: `.github/workflows/release.yml`, `web/presskit.html` and `tests/lua/save_compat_test.lua`.
- Changed: `CMakePresets.json`, `.github/workflows/ci.yml` (the press kit in the site), `fk/save.lua` and
  `tests/lua/save_test.lua`.
