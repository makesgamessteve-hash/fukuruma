// Automatic exposure with eye adaptation: moves the previous exposure towards the target.
#ifdef FRAGMENT
uniform sampler2D u_luminance;
uniform sampler2D u_previous;
uniform float u_lod;
uniform float u_adapt;
uniform float u_bias;
out vec4 o_color;
void main() {
    float average = exp(textureLod(u_luminance, vec2(0.5), u_lod).r);
    float target = clamp(0.18 / max(average, 1e-4) * u_bias, 0.03, 30.0);
    o_color = vec4(mix(texture(u_previous, vec2(0.5)).r, target, u_adapt));
}
#endif
