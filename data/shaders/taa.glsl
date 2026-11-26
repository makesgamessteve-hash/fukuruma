// Temporal anti-aliasing: reproject the history by depth, clamp it to this frame's 3x3 neighbourhood, blend.
#ifdef FRAGMENT
uniform sampler2D u_current;
uniform sampler2D u_history;
uniform sampler2D u_depth;
uniform mat4 u_inv_view_proj;
uniform mat4 u_prev_view_proj;
uniform vec2 u_texel;
uniform float u_valid;
out vec4 o_color;
void main() {
    vec3 c = texture(u_current, v_uv).rgb, lo = c, hi = c;
    for (int x = -1; x <= 1; x++)
        for (int y = -1; y <= 1; y++) {
            vec3 s = texture(u_current, v_uv + vec2(x, y) * u_texel).rgb;
            lo = min(lo, s);
            hi = max(hi, s);
        }
    vec4 world = u_inv_view_proj * vec4(vec3(v_uv, texture(u_depth, v_uv).r) * 2.0 - 1.0, 1.0);
    vec4 prev = u_prev_view_proj * vec4(world.xyz / world.w, 1.0);
    vec2 uv = prev.xy / prev.w * 0.5 + 0.5;
    if (u_valid < 0.5 || any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
        o_color = vec4(c, 1.0); // nothing to reproject from
        return;
    }
    vec3 history = clamp(texture(u_history, uv).rgb, lo, hi); // clamping prevents ghost trails
    o_color = vec4(mix(history, c, 0.1), 1.0);
}
#endif
