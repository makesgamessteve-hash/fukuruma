// Scene meshes into the G-buffer: base colour + metalness, normal + roughness, emission.
#ifdef VERTEX
in vec3 a_position;
in vec3 a_color;
in vec3 a_normal;
in vec2 a_uv;
in vec4 a_tangent;
uniform mat4 u_model;
uniform mat4 u_view_proj;
out vec3 v_color;
out vec3 v_normal;
out vec2 v_uv;
out vec4 v_tangent;
out vec3 v_object; // the vertex in the mesh's own space (terrain: metres from the chunk's centre, planet axes)
out vec2 v_layers; // terrain: snow and wetness (planet chunks keep them in the tangent, which they do not use)
out vec3 v_world;  // draw axes
void main() {
    mat4 model = u_model * skin_matrix();
    mat3 m = mat3(model); // shortcut: assumes uniform scale; add a normal matrix for non-uniform scaling
    v_color = a_color * (u_instanced == 1 ? a_inst1.y : 1.0);
    v_normal = m * instance_turn(a_normal);
    v_uv = a_uv;
    v_tangent = vec4(m * a_tangent.xyz, a_tangent.w);
    v_object = a_position;
    v_layers = a_tangent.xy;
    vec4 world = u_model * vec4(instance_point((skin_matrix() * vec4(a_position, 1.0)).xyz), 1.0);
    v_world = world.xyz;
    gl_Position = u_view_proj * world;
}
#endif

#ifdef FRAGMENT
in vec3 v_color;
in vec3 v_normal;
in vec2 v_uv;
in vec4 v_tangent;
in vec3 v_object;
in vec2 v_layers;
in vec3 v_world;
uniform vec4 u_base;
uniform float u_roughness;
uniform float u_metalness;
uniform vec3 u_emission;
uniform float u_emissive_colors; // 1: the vertex colours tint the emission (stars), not the base colour
uniform float u_normal_scale; // 0: no normal map
uniform float u_clouds;       // planet chunks: how much of the cloud cover in v_uv.x shows (fades as one comes closer)
uniform float u_one_sided;    // 1: keep normals on back faces (closed surfaces such as planets)
uniform float u_indoor;       // 1: rooms inside a doll, out of the starlight (the normal's alpha tells the lighting)
uniform sampler2D u_base_tex;        // sRGB texture: sampled as linear
uniform sampler2D u_metal_rough_tex; // glTF layout: green roughness, blue metalness
uniform sampler2D u_normal_tex;
uniform sampler2D u_emission_tex;    // sRGB texture
uniform mat4 u_model;
uniform float u_terrain;         // > 0: the terrain material (terrain-materials spec), at this quality (1 to 3)
uniform vec3 u_terrain_origin;   // the chunk's centre (planet axes, metres) wrapped to PERIOD: detail runs on across chunks
uniform vec3 u_terrain_up;       // the world's up at the chunk (draw axes)
uniform vec3 u_weather;          // extra wetness, snow and dust from the weather
layout(location = 0) out vec4 o_base;

// Terrain detail: solid (3D) value noise, so it needs no projection and wraps with the chunk origins every PERIOD metres.
const float PERIOD = 256.0;
float lattice(vec3 c, float cells) {
    uvec3 q = uvec3(mod(c, cells));
    uint h = q.x * 73856093u ^ q.y * 19349663u ^ q.z * 83492791u;
    h = (h ^ (h >> 13u)) * 1274126177u;
    return float(h >> 16u) / 65535.0;
}
float value_noise(vec3 p, float cells) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(lattice(i, cells), lattice(i + vec3(1, 0, 0), cells), f.x),
                   mix(lattice(i + vec3(0, 1, 0), cells), lattice(i + vec3(1, 1, 0), cells), f.x), f.y),
               mix(mix(lattice(i + vec3(0, 0, 1), cells), lattice(i + vec3(1, 0, 1), cells), f.x),
                   mix(lattice(i + vec3(0, 1, 1), cells), lattice(i + vec3(1, 1, 1), cells), f.x), f.y), f.z);
}
// Detail in -0.5..0.5 at cells of `size` metres, faded out where a cell would be smaller than about a pixel.
float detail(vec3 p, float size, float footprint) {
    return (value_noise(p / size, PERIOD / size) - 0.5) * (1.0 - smoothstep(0.35, 1.0, footprint / size));
}

// The terrain material over the chunk's colours: fine detail and bumps, rock on steep ground, snow on the level,
// wetness (darker, glossier) and wind-blown dust. Returns the roughness; changes base and n.
float terrain_material(inout vec3 base, inout vec3 n, float roughness) {
    vec3 p = u_terrain_origin + v_object;
    float footprint = length(fwidth(p));
    // u_terrain is the material's quality (the graphics level): 1 layers only, 2 with detail, 3 with bumps as well
    float fine = 0.0, coarse = 0.0;
    if (u_terrain > 1.5) {
        fine = detail(p, 0.4, footprint) + 0.6 * detail(p, 1.6, footprint);
        coarse = detail(p, 6.4, footprint) + 0.7 * detail(p, 25.6, footprint);
    }
    vec3 up = normalize(u_terrain_up);
    float level = dot(n, up);
    float steep = 1.0 - smoothstep(0.76, 0.92, level + coarse * 0.2); // rock from about 25 degrees
    float wet = clamp(v_layers.y + u_weather.x, 0.0, 1.0);
    // bumps: the gradient of the detail's height by differences in the chunk's own space, turned into draw axes
    // (screen-space derivatives tip single pixels over at triangle edges)
    float amp = 0.25 * (0.4 + steep);
    float h0 = fine * 0.06 + coarse * amp;
    if (u_terrain > 2.5) {
    const float E = 0.05;
    vec3 grad = vec3(detail(p + vec3(E, 0, 0), 0.4, footprint) + 0.6 * detail(p + vec3(E, 0, 0), 1.6, footprint),
                     detail(p + vec3(0, E, 0), 0.4, footprint) + 0.6 * detail(p + vec3(0, E, 0), 1.6, footprint),
                     detail(p + vec3(0, 0, E), 0.4, footprint) + 0.6 * detail(p + vec3(0, 0, E), 1.6, footprint)) * 0.06
               + vec3(detail(p + vec3(E, 0, 0), 6.4, footprint) + 0.7 * detail(p + vec3(E, 0, 0), 25.6, footprint),
                      detail(p + vec3(0, E, 0), 6.4, footprint) + 0.7 * detail(p + vec3(0, E, 0), 25.6, footprint),
                      detail(p + vec3(0, 0, E), 6.4, footprint) + 0.7 * detail(p + vec3(0, 0, E), 25.6, footprint)) * amp;
    grad = mat3(u_model) * ((grad - h0) / E);
    grad -= n * dot(n, grad); // along the surface
    float gl = length(grad);
    n = normalize(n - grad * (min(gl, 0.35) / max(gl, 1e-6)) * (1.0 - 0.7 * wet)); // at most about 19 degrees
    }
    base *= 0.82 + 0.5 * fine + 0.3 * coarse;
    vec3 rock = vec3(dot(base, vec3(0.3, 0.5, 0.2))) * vec3(1.05, 0.98, 0.9) * (0.8 + 0.6 * coarse) + 0.04;
    base = mix(base, rock, steep);
    roughness = mix(roughness, 0.75, steep);
    float snow = clamp(v_layers.x + u_weather.y, 0.0, 1.0) * smoothstep(0.45, 0.8, level);
    snow = smoothstep(0.35, 0.65, snow + fine * 0.5);
    base = mix(base, vec3(0.86, 0.9, 0.95) * (0.95 + 0.2 * fine), snow);
    roughness = mix(roughness, 0.55, snow);
    wet *= 1.0 - snow;
    base *= mix(1.0, 0.45, wet * (1.0 - steep * 0.5));
    roughness = mix(roughness, 0.12, wet);
    float dust = u_weather.z * smoothstep(0.3, 0.9, level) * (1.0 - snow);
    base = mix(base, vec3(0.58, 0.46, 0.32) * (0.9 + 0.3 * coarse), dust * 0.8);
    return mix(roughness, 0.95, dust);
}
layout(location = 1) out vec4 o_normal;
layout(location = 2) out vec4 o_emission;
void main() {
    if (u_ndigs > 0 && dug(v_world)) discard;
    vec3 n = normalize(gl_FrontFacing || u_one_sided > 0.5 ? v_normal : -v_normal);
    if (u_normal_scale > 0.0) {
        vec3 t = v_tangent.xyz - n * dot(n, v_tangent.xyz);
        if (dot(t, t) > 1e-8) {
            t = normalize(t);
            vec3 tn = texture(u_normal_tex, v_uv).xyz * 2.0 - 1.0;
            tn.xy *= u_normal_scale;
            n = normalize(mat3(t, cross(n, t) * v_tangent.w, n) * tn);
        }
    }
    vec3 base = srgb_to_linear(v_color) * u_base.rgb * texture(u_base_tex, v_uv).rgb; // shortcut: alpha is ignored (opaque)
    if (u_clouds > 0.0) base = mix(base, vec3(0.89, 0.91, 0.95), v_uv.x * u_clouds); // the cloud layer from afar
    vec4 mr = texture(u_metal_rough_tex, v_uv);
    float roughness = u_roughness * mr.g;
    if (u_terrain > 0.5) {
        vec3 smooth_n = n;
        roughness = terrain_material(base, n, roughness);
        if (!(dot(n, n) > 0.5)) n = smooth_n; // never a NaN into the G-buffer (false for NaN as well)
        if (!(base.r + base.g + base.b >= 0.0)) base = srgb_to_linear(v_color);
    }
    o_base = vec4(linear_to_srgb(base), u_metalness * mr.b); // sRGB colour: better precision in 8 bits than linear
    o_normal = vec4(encode_normal(n), roughness, 1.0 - u_indoor);
    vec3 e = u_emission * texture(u_emission_tex, v_uv).rgb;
    if (u_emissive_colors > 0.5) e *= srgb_to_linear(v_color);
    float strength = max(max(e.r, e.g), e.b);
    o_emission = vec4(strength > 0.0 ? e / strength : vec3(0.0), min(strength / 16.0, 1.0));
}
#endif
