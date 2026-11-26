// 4x4 box blur (ambient occlusion).
#ifdef FRAGMENT
uniform sampler2D u_input;
uniform vec2 u_texel;
out vec4 o_color;
void main() {
    float sum = 0.0;
    for (int x = -2; x < 2; x++)
        for (int y = -2; y < 2; y++) sum += texture(u_input, v_uv + (vec2(x, y) + 0.5) * u_texel).r;
    o_color = vec4(sum / 16.0);
}
#endif
