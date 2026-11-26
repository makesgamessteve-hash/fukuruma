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
void main() {
    mat4 model = u_model * skin_matrix();
    mat3 m = mat3(model); // shortcut: assumes uniform scale; add a normal matrix for non-uniform scaling
    v_color = a_color;
    v_normal = m * a_normal;
    v_uv = a_uv;
    v_tangent = vec4(m * a_tangent.xyz, a_tangent.w);
    gl_Position = u_view_proj * (model * vec4(a_position, 1.0));
}
#endif

#ifdef FRAGMENT
in vec3 v_color;
in vec3 v_normal;
in vec2 v_uv;
in vec4 v_tangent;
uniform vec4 u_base;
uniform float u_roughness;
uniform float u_metalness;
uniform vec3 u_emission;
uniform float u_normal_scale; // 0: no normal map
uniform sampler2D u_base_tex;        // sRGB texture: sampled as linear
uniform sampler2D u_metal_rough_tex; // glTF layout: green roughness, blue metalness
uniform sampler2D u_normal_tex;
uniform sampler2D u_emission_tex;    // sRGB texture
layout(location = 0) out vec4 o_base;
layout(location = 1) out vec4 o_normal;
layout(location = 2) out vec4 o_emission;
void main() {
    vec3 n = normalize(gl_FrontFacing ? v_normal : -v_normal);
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
    vec4 mr = texture(u_metal_rough_tex, v_uv);
    o_base = vec4(linear_to_srgb(base), u_metalness * mr.b); // sRGB colour: better precision in 8 bits than linear
    o_normal = vec4(encode_normal(n), u_roughness * mr.g, 1.0);
    vec3 e = u_emission * texture(u_emission_tex, v_uv).rgb;
    float strength = max(max(e.r, e.g), e.b);
    o_emission = vec4(strength > 0.0 ? e / strength : vec3(0.0), min(strength / 16.0, 1.0));
}
#endif
