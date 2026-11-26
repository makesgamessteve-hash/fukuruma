# Fukuruma

**▶ Play in your browser: <https://makesgamessteve-hash.github.io/fukuruma/>**

A space exploration game about wonder and scale: modern lighting, effects and animation, seen
through a retro low-resolution filter. You command a moon-sized Jump Ship that carries space
stations, which carry flying mountains, which carry walking cities, which carry giant walkers, which
carry you, in an environmental exosuit. Every doll in the chain can be deployed, boarded and
explored. Every planet is worth going down to, and any planet can kill you.

| Doll | Size |
|------|------|
| Jump Ship | 144 km |
| Space Station | ≈ 31 km |
| Continental Explorer | ≈ 6.7 km |
| Land Explorer | 1.44 km |
| Exploration Walker | 72 m |
| Exosuit | 3.6 m |

## Status

Planning is done; implementation starts with milestone M0 (build, test and deployment pipeline).
The link above works once M0 has been deployed and GitHub Pages is enabled for this repository.

- [Game concept](docs/CONCEPT.md)
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)
- [OpenSpec changes](openspec/changes/) and [specs](openspec/specs/)

## Technology

- Core engine in **C11** with **SDL3** and **OpenGL** (3.3 core, ES 3.0, WebGL 2)
- Game logic in **Lua 5.4**; scripts, shaders and assets live in `data/` beside the binary, mods in `mods/`
- Targets: Windows, Linux, macOS, Web (Emscripten, with touch controls on mobile) and WebXR
- Spec-driven development with [OpenSpec](https://github.com/Fission-AI/OpenSpec); agent rules from
  [ponytail](https://github.com/DietrichGebert/ponytail) in [AGENTS.md](AGENTS.md)
- Unit tests with at least 95% line coverage, plus automated game tests

## One-time repository setup

GitHub Pages must be enabled once: **Settings → Pages → Build and deployment → Source: GitHub Actions**.

## Licences

- Code (C, Lua, GLSL, JavaScript, tools): [MIT](LICENSE)
- Art (textures, models, voxels, sprites, palettes, sounds, music): [CC BY 4.0](LICENSE-ASSETS.md)
- Third-party components: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
