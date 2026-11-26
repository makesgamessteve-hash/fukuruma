# Design

## Context

M0/M1 draw unlit coloured meshes directly to the window. The plan (§3.4) describes a deferred, HDR,
physically based pipeline at a low internal resolution within the WebGL 2 baseline (no compute,
geometry or tessellation shaders). This change builds its core; detail levels and the menu follow in
`add-graphics-settings`.

## Goals / Non-Goals

**Goals:** internal-resolution rendering with integer upscale; G-buffer; PBR lighting with a star,
ambient and point lights; cascaded shadows; SSAO; bloom; auto exposure; tone mapping and grading;
dithering; supersampling; LDR fallback; overlay; runtime configuration; deterministic output for tests.

**Non-Goals:** TAA, palette mode, text and menus (next change); textures and glTF (asset loading);
image-based lighting from a real sky, fog and atmosphere (M4/M5); local-light shadows (later, when
interiors need them).

## Decisions

### Recording, then rendering
`fk.gfx.draw`, `light`, `camera` and `overlay` only record into a per-frame list (`gfx/frame.c`, plain C,
unit-tested without GL). After the game's `draw`, the app calls `fk_gfx_render(dt)`, which runs the
passes (`gfx/gl_pipeline.c`). No-render runs record and validate but never render.

### Targets (all at internal resolution × supersample)
- G-buffer: RT0 `RGBA8` base colour + metalness; RT1 `RGB10_A2` octahedral normal + roughness;
  RT2 `RGBA8` emission colour + emission strength / 16; depth `DEPTH_COMPONENT24` (a texture, read
  back for positions). None of these need float support.
- Lighting `RGBA16F` (or `RGBA8` in the LDR fallback), SSAO `R8`, bloom chain `RGBA16F` at 1/2…1/16,
  luminance `R16F` 64×32 with mipmaps, two 1×1 `R16F` exposure targets (ping-pong for adaptation).
- Final `RGBA8` image at the internal resolution: supersampled output is filtered down with a linear
  blit (exactly a 2×2 box filter). The overlay is drawn onto it; screenshots read it; the window gets
  a nearest-neighbour blit into the integer-scaled, centred rectangle.

### Shadows
Practical split scheme (λ = 0.75) up to a shadow distance of 80 units. Each cascade uses the bounding
sphere of its frustum slice (stable size), a light view along the star direction and a centre snapped to
whole texels (`gfx/shadow.c`, unit-tested). Depth goes into one `DEPTH_COMPONENT24` texture array with
hardware comparison; the lighting pass picks the cascade by view depth and filters with 4 taps of
`sampler2DArrayShadow` (hardware 2×2 PCF each), with slope-scaled polygon offset and a normal offset.

### Lighting
GGX/Smith/Schlick specular with Lambert diffuse; ambient from a sky/ground hemisphere with a Schlick
fresnel term for specular ambient; point lights with inverse-square falloff windowed to their radius;
emission added. Vertex colours are sRGB and converted to linear in the G-buffer pass.

### SSAO
Normal-oriented hemisphere sampling of the depth buffer, 0–16 samples with a per-pixel rotation from an
integer hash (deterministic), radius 0.6 units, followed by a 4×4 blur. Applied to ambient light only.

### Post
Bright-pass with a soft knee, 4-level down/up-sample bloom; log-average luminance from the mip chain,
exposure adapting exponentially (time constant 0.7 s, frame time passed in, so scenarios are reproducible);
ACES-fitted tone curve; grading (exposure bias, contrast, saturation, tint); sRGB encode; 4×4 Bayer dither.

### Configuration
`fk.gfx.configure{ width, height, supersample, shadow_cascades, shadow_size, ao_samples, bloom,
max_lights, hdr, dither }` validates, then recreates targets and recompiles shader variants (counts
become `#define`s). The engine forces `hdr = false` when `GL_EXT_color_buffer_float` is missing on
OpenGL ES.

### Input mapping to the image
The pipeline publishes the image rectangle inside the window; `fk.input` maps mouse and touch positions
into it (identity without a window).

## Risks / Trade-offs

- **CI time on llvmpipe** → modest test settings; scenarios render few hundred frames at most.
- **Normal precision** (10-bit octahedral) → enough at the internal resolution; revisit if banding shows.
- **No TAA yet** → supersampling covers stability for now; TAA lands with the detail levels.
- **Pillar/letterbox bars on phones** → the internal image is 16:9; matching the window's aspect is a
  graphics-settings option later.
