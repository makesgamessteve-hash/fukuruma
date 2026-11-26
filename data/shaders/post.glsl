// Exposure, bloom, tone curve, grading, sRGB, ordered dithering and the palette mode into the 8-bit image.
#ifdef FRAGMENT
uniform sampler2D u_input;
uniform sampler2D u_bloom;
uniform sampler2D u_exposure;
uniform float u_contrast;
uniform float u_saturation;
uniform vec3 u_tint;
uniform vec3 u_palette[64]; // sRGB
uniform int u_palette_size; // 0: palette mode off
out vec4 o_color;

vec3 toned(vec2 uv) { // exposure, bloom and the tone curve: 0..1
    vec3 c = texture(u_input, uv).rgb;
#ifdef HDR
    c *= texture(u_exposure, vec2(0.5)).r;
#ifdef BLOOM
    c += texture(u_bloom, uv).rgb * 0.08;
#endif
    c = aces(c);
#endif
    return c;
}

void main() {
    vec3 c = toned(v_uv);
#ifdef TAA // TAA averages jittered frames, about a pixel of blur: contrast-adaptive sharpening (after AMD's CAS) restores it
    vec2 t = 1.0 / vec2(textureSize(u_input, 0));
    vec3 n = toned(v_uv + vec2(0.0, t.y)), s = toned(v_uv - vec2(0.0, t.y));
    vec3 e = toned(v_uv + vec2(t.x, 0.0)), w = toned(v_uv - vec2(t.x, 0.0));
    vec3 lo = min(c, min(min(n, s), min(e, w))), hi = max(c, max(max(n, s), max(e, w)));
    vec3 amount = sqrt(clamp(min(lo, 1.0 - hi) / max(hi, vec3(1e-4)), 0.0, 1.0)) * (-1.0 / 5.0); // full strength
    c = clamp((c + (n + s + e + w) * amount) / (1.0 + 4.0 * amount), 0.0, 1.0);
#endif
    c *= u_tint;
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(l), c, u_saturation);
    c = clamp((c - 0.18) * u_contrast + 0.18, 0.0, 1.0);
    c = pow(c, vec3(1.0 / 2.2));
    const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    ivec2 q = ivec2(gl_FragCoord.xy) & 3;
    float threshold = bayer[q.y * 4 + q.x] / 16.0 - 0.5;
    if (u_palette_size > 0) { // ordered dithering into the palette: the strong retro look
        c += threshold / 8.0;
        vec3 pick = u_palette[0];
        float best = 1e9;
        for (int i = 0; i < 64; i++) {
            if (i >= u_palette_size) break;
            vec3 d = c - u_palette[i];
            float e = dot(d, d);
            if (e < best) {
                best = e;
                pick = u_palette[i];
            }
        }
        c = pick;
    }
#ifdef DITHER
    else c += threshold / 255.0;
#endif
    o_color = vec4(c, 1.0);
}
#endif
