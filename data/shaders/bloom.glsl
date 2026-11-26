// Bloom: bright-pass (PREFILTER), 4-tap downsample, 3x3 tent upsample (UP, added by blending).
#ifdef FRAGMENT
uniform sampler2D u_input;
uniform sampler2D u_exposure;
uniform vec2 u_texel;
out vec4 o_color;
vec3 at(vec2 offset) { return texture(u_input, v_uv + offset * u_texel).rgb; }
void main() {
#ifdef UP
    vec3 s = at(vec2(0.0)) * 4.0 + (at(vec2(-1.0, 0.0)) + at(vec2(1.0, 0.0)) + at(vec2(0.0, -1.0)) + at(vec2(0.0, 1.0))) * 2.0 +
             at(vec2(-1.0, -1.0)) + at(vec2(1.0, -1.0)) + at(vec2(-1.0, 1.0)) + at(vec2(1.0, 1.0));
    o_color = vec4(s / 16.0, 1.0);
#else
    vec3 s = 0.25 * (at(vec2(-1.0, -1.0)) + at(vec2(1.0, -1.0)) + at(vec2(-1.0, 1.0)) + at(vec2(1.0, 1.0)));
#ifdef PREFILTER
    s *= texture(u_exposure, vec2(0.5)).r; // threshold in exposed units: what looks bright, blooms
    float b = max(s.r, max(s.g, s.b)), threshold = 1.0, knee = 0.5;
    float soft = clamp(b - threshold + knee, 0.0, 2.0 * knee);
    s *= max(soft * soft / (4.0 * knee), b - threshold) / max(b, 1e-4);
#endif
    o_color = vec4(s, 1.0);
#endif
}
#endif
