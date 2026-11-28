# Modding Fukuruma

A mod is a folder under `mods/` beside the game's executable. It can **replace files** of the game and **add content**
through the game's registries. `mods/example-mod/` is a small working example.

Mods are loaded on the desktop builds (Windows, Linux, macOS). The web build has only the game's own `data/`.

## The manifest

`mods/<folder>/mod.lua` returns a table of data. It is not run as code with access to the game: it is read in an
empty environment.

```lua
return {
  name = "My mod",          -- shown in logs
  version = "1.0",
  order = 10,               -- load order, lowest first (ties: by folder name)
  script = "mymod.init",    -- optional: a module the game requires once its own modules are loaded
  enabled = true,           -- false: the mod is skipped
}
```

Folder names may only contain letters, digits, `_` and `-`.

## Replacing files

Every file the game reads (scripts, shaders, models, textures, sounds, music) is looked up first in the mods, the last
one in load order first, and then in `data/`. To replace a file, put a file with the same path under your mod's
folder. For example, `mods/my-mod/sounds/door.ogg` replaces `data/sounds/door.ogg`.

The game's first script, `scripts/main.lua`, is read before the mods are known, so it cannot be replaced. Replacing
whole game modules is possible, but fragile across versions; prefer adding content.

## Adding content

A mod's script is a Lua module (`mods/<folder>/scripts/<name>.lua`, required by the manifest's `script`). It runs in
the same sandbox as the game's scripts: no file or OS access, and randomness only from seeded streams (`fk.rng`).

| What | How | Format |
|---|---|---|
| A doll | `require("dolls").register(def)` | `data/scripts/dolls/*.lua` |
| A marvel | `require("gen.wonders").register(def)` | `data/scripts/gen/wonders.lua` |
| A hazard kind | `require("sensors").HAZARDS.<kind> = {...}` | `data/scripts/sensors.lua` |
| Things living on each world | `table.insert(require("sensors").world_hooks, fn)` | `fn(key, hazards, next_id)` |
| A research project | `require("research").register(node)` | `data/scripts/research/tree.lua` |
| A story thread | `require("story").register(thread)` | `data/scripts/story/signal.lua` |
| A dialogue tree or menu | `require("dialogue").register(name, tree)` | `data/scripts/dialogue/natives.lua` |
| A recipe, good or outpost module | append to `require("economy").RECIPES`, `.GOODS` or `.MODULES` | `data/scripts/economy.lua` |
| A feedback bundle | `require("feedback").<event> = {...}` | `data/scripts/feedback.lua` |
| A language | a file `scripts/strings/<language>.lua` | `data/scripts/strings/en.lua` |

## Rules that keep saves and multiplayer working

- **Determinism.** The simulation must give the same result everywhere. Use `fk.rng(...)` streams and the `fk.math`
  helpers in simulation code, never `math.random`, and do not let iteration order (`pairs`) decide anything.
- **Simulation and presentation.** Drawing, sounds and particles react to simulation events (`sim.emit`, listened
  to with `sim.listen`). They never change simulation state.
- **State.** Anything that must survive a save lives in a simulation component (`sim.set(id, name, table)`). Module
  variables are lost on loading.

## The example mod

`mods/example-mod/` adds a research project, "Long ping", and a hazard kind, the crystal bloom. Its manifest names
`example.init`, which is `mods/example-mod/scripts/example/init.lua`. `tests/lua/mods_test.lua` checks that it loads.
