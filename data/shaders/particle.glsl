// Particles: camera-facing quads, round and soft, tested against the G-buffer depth in the shader (the depth
// texture is read, not attached, so the pass is legal on WebGL 2) and faded where they meet surfaces.
#ifdef VERTEX
in vec3 a_position;
in vec4 a_color;
in vec2 a_uv;
uniform mat4 u_view_proj;
out vec4 v_color;
out vec2 v_uv;
void main() {
    v_color = a_color;
    v_uv = a_uv;
    gl_Position = u_view_proj * vec4(a_position, 1.0);
}
#endif

#ifdef FRAGMENT
in vec4 v_color;
in vec2 v_uv;
uniform sampler2D u_depth;
uniform float u_near;
uniform float u_far;
uniform vec3 u_light; // ambient and star light for dust
uniform float u_glow; // 1: added light, unlit
out vec4 o_color;
float linear_depth(float d) { return u_near * u_far / (u_far - d * (u_far - u_near)); }
void main() {
    vec2 p = v_uv * 2.0 - 1.0;
    float shape = 1.0 - smoothstep(0.35, 1.0, dot(p, p));
    float scene = linear_depth(texelFetch(u_depth, ivec2(gl_FragCoord.xy), 0).r);
    float soft = clamp((scene - linear_depth(gl_FragCoord.z)) / 0.4, 0.0, 1.0); // 0.4 m soft edge
    float a = v_color.a * shape * soft;
    if (a <= 0.003) discard;
    if (u_glow > 0.5) o_color = vec4(v_color.rgb * a, 1.0);
    else o_color = vec4(v_color.rgb * u_light, a);
}
#endif
