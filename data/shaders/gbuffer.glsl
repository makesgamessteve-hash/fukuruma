// Scene meshes into the G-buffer: base colour + metalness, normal + roughness, emission.
#ifdef VERTEX
in vec3 a_position;
in vec3 a_color;
in vec3 a_normal;
uniform mat4 u_model;
uniform mat4 u_view_proj;
out vec3 v_color;
out vec3 v_normal;
void main() {
    v_color = a_color;
    v_normal = mat3(u_model) * a_normal; // shortcut: assumes uniform scale; add a normal matrix for non-uniform scaling
    gl_Position = u_view_proj * (u_model * vec4(a_position, 1.0));
}
#endif

#ifdef FRAGMENT
in vec3 v_color;
in vec3 v_normal;
uniform float u_roughness;
uniform float u_metalness;
uniform vec3 u_emission;
layout(location = 0) out vec4 o_base;
layout(location = 1) out vec4 o_normal;
layout(location = 2) out vec4 o_emission;
void main() {
    vec3 n = normalize(gl_FrontFacing ? v_normal : -v_normal);
    o_base = vec4(v_color, u_metalness); // sRGB colour: better precision in 8 bits than linear
    o_normal = vec4(encode_normal(n), u_roughness, 1.0);
    float strength = max(max(u_emission.r, u_emission.g), u_emission.b);
    o_emission = vec4(strength > 0.0 ? u_emission / strength : vec3(0.0), min(strength / 16.0, 1.0));
}
#endif
