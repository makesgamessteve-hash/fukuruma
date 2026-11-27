// Log luminance of the lit image into a small target; its mip chain gives the average. Empty sky counts as at least
// dim (0.05), so the eye does not adapt to black space as if it were a dark room and blow out a lit planet.
#ifdef FRAGMENT
uniform sampler2D u_input;
uniform sampler2D u_depth;
out vec4 o_color;
void main() {
    vec3 c = texture(u_input, v_uv).rgb;
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    if (is_sky(texture(u_depth, v_uv).r)) l = max(l, 0.05);
    o_color = vec4(log(max(l, 1e-4)));
}
#endif
