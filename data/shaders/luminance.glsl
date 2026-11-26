// Log luminance of the lit image into a small target; its mip chain gives the average.
#ifdef FRAGMENT
uniform sampler2D u_input;
out vec4 o_color;
void main() {
    vec3 c = texture(u_input, v_uv).rgb;
    o_color = vec4(log(max(dot(c, vec3(0.2126, 0.7152, 0.0722)), 1e-4)));
}
#endif
