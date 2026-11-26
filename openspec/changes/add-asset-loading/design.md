# Design

## Context

The engine draws meshes from Lua tables with per-vertex colours and per-draw roughness, metalness and
emission. M1 needs models, textures and sounds from files, and the animation change after this one
needs skins and clips in memory.

## Decisions

### cgltf and stb, not a converter
cgltf (MIT, one header) parses glTF directly; stb_image already decodes PNG and gains JPEG, and
stb_vorbis decodes OGG. No offline conversion step: modders drop `.glb` files into `data/`. Files are
read through the VFS with cgltf's file callbacks, and `cgltf_validate` bounds-checks accessors and
indices, because models may come from mods.

### Files stay inside data/
Paths given to `fk.gfx.texture` and `fk.gfx.model` must be relative and use only letters, digits,
`_ - . /` without `..`. Buffer and image URIs inside a glTF file are checked the same way after
joining them to the model's folder; data URIs are allowed.

### One vertex layout
`fk_vertex` holds position, sRGB colour, normal, UV, tangent (with the bitangent sign), four joint
indices and four weights — 23 floats. One layout keeps one VAO setup and one shader input list;
memory is not a concern for M1's meshes (terrain gets its own format in M5). glTF vertex colours are
linear and stored as sRGB to match Lua meshes. Missing normals are computed from the triangles;
missing tangents (when a normal map is used) from the UVs (averaged per vertex, not MikkTSpace — the
generated models bake their tangents).

### Materials in the G-buffer pass
`fk_material` gains a linear base factor, a normal scale and four texture pointers. The pipeline binds
a white texture for missing slots and passes normal scale 0 when there is no normal map, so untextured
meshes cost four texture lookups and no branches beyond one uniform test. Base colour and emission
textures are sRGB textures (sampled as linear); the G-buffer keeps storing sRGB base colour. Alpha is
ignored (opaque).

### Models in memory
`fk_model` keeps nodes (rest TRS and model-space matrices), primitives, materials, skins and clips as
plain arrays, so the animation runtime can sample them without cgltf. GPU meshes and textures are
created by `fk_model_upload`, which drops the CPU copies; without rendering they stay on the CPU.
Each glTF mesh becomes a run of primitives referenced by its nodes. Images take their colour space from
the first material slot that uses them.

### Caching and lifetime
Textures and models are Lua userdata cached by path in a weak registry table, so loading the same path
twice returns the same object and unused ones are collected. A draw keeps its model or texture alive
until the frame is rendered.

### Hot reload
`assets/watch.c` remembers full paths with modification time and size and calls back when either
changes. The app polls every 0.5 s on desktop debug builds with a window. Shaders set a flag that
reconfigures the pipeline; scripts set a flag that closes the Lua state and starts the game again
(which also clears a script-error screen once the file is fixed). Textures and models reload in place
(the userdata keeps its address); if the new file fails, the old data stays and the reason is logged.

### Sounds
`fk_sound_decode` returns interleaved float samples at 48 kHz, mono or stereo, at most 60 s: the
length is checked before decoding (OGG) so a large file cannot exhaust memory. Resampling and WAV
parsing use SDL (`platform/`), Vorbis uses stb_vorbis. Music is streamed by the audio change.

### `require("game")`
The table returned by `main.lua` is registered as module `game`. Showcase scenarios replace
`game.draw` with their scene; mods will extend the game through it.

## Risks / Trade-offs

- Rigid placeholder art: the Exosuit is built from boxes with rigid skinning; real art replaces it later.
- Texture lookups for every draw: four per pixel even without textures; fine at the internal resolution.
