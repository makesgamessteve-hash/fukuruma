// Exposure, bloom, tone curve, grading, sRGB and ordered dithering into the 8-bit image.
#ifdef FRAGMENT
uniform sampler2D u_input;
uniform sampler2D u_bloom;
uniform sampler2D u_exposure;
uniform float u_contrast;
uniform float u_saturation;
uniform vec3 u_tint;
out vec4 o_color;
void main() {
    vec3 c = texture(u_input, v_uv).rgb;
#ifdef HDR
    c *= texture(u_exposure, vec2(0.5)).r;
#ifdef BLOOM
    c += texture(u_bloom, v_uv).rgb * 0.08;
#endif
    c = aces(c);
#endif
    c *= u_tint;
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(l), c, u_saturation);
    c = clamp((c - 0.18) * u_contrast + 0.18, 0.0, 1.0);
    c = pow(c, vec3(1.0 / 2.2));
#ifdef DITHER
    const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    ivec2 q = ivec2(gl_FragCoord.xy) & 3;
    c += (bayer[q.y * 4 + q.x] / 16.0 - 0.5) / 255.0;
#endif
    o_color = vec4(c, 1.0);
}
#endif
