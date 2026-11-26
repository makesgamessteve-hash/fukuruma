// Temporal anti-aliasing: reproject the history by depth, clamp it to this frame's 3x3 neighbourhood, blend.
// The history is read with a Catmull-Rom filter: plain bilinear reads blur a little more every frame the camera
// moves, which at a low internal resolution soon softens the whole picture.
#ifdef FRAGMENT
uniform sampler2D u_current;
uniform sampler2D u_history;
uniform sampler2D u_depth;
uniform mat4 u_inv_view_proj;
uniform mat4 u_prev_view_proj;
uniform vec2 u_texel;
uniform float u_valid;
out vec4 o_color;

vec3 history_at(vec2 uv) { // Catmull-Rom in five bilinear reads (the four corner taps are dropped)
    vec2 pos = uv / u_texel, center = floor(pos - 0.5) + 0.5, f = pos - center, f2 = f * f, f3 = f2 * f;
    vec2 w0 = -0.5 * f3 + f2 - 0.5 * f, w1 = 1.5 * f3 - 2.5 * f2 + 1.0, w2 = -1.5 * f3 + 2.0 * f2 + 0.5 * f;
    vec2 w3 = 0.5 * f3 - 0.5 * f2, w12 = w1 + w2;
    vec2 t0 = (center - 1.0) * u_texel, t12 = (center + w2 / w12) * u_texel, t3 = (center + 2.0) * u_texel;
    vec3 sum = texture(u_history, vec2(t12.x, t0.y)).rgb * (w12.x * w0.y) +
               texture(u_history, vec2(t0.x, t12.y)).rgb * (w0.x * w12.y) +
               texture(u_history, t12).rgb * (w12.x * w12.y) +
               texture(u_history, vec2(t3.x, t12.y)).rgb * (w3.x * w12.y) +
               texture(u_history, vec2(t12.x, t3.y)).rgb * (w12.x * w3.y);
    float weight = w12.x * w0.y + w0.x * w12.y + w12.x * w12.y + w3.x * w12.y + w12.x * w3.y;
    return max(sum / weight, vec3(0.0));
}

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
    vec3 history = clamp(history_at(uv), lo, hi); // clamping prevents ghost trails
    float moved = length((uv - v_uv) / u_texel);  // pixels since the last frame
    o_color = vec4(mix(history, c, mix(0.1, 0.25, clamp(moved / 4.0, 0.0, 1.0))), 1.0);
}
#endif
