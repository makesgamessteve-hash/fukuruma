// Text and rectangles: quads in internal-image pixels, tinted by their colour, alpha from the font atlas.
#ifdef VERTEX
in vec4 a_position; // x, y in pixels (y down), u, v
in vec4 a_color;
uniform vec2 u_size;
out vec2 v_uv;
out vec4 v_color;
void main() {
    v_uv = a_position.zw;
    v_color = a_color;
    vec2 p = a_position.xy / u_size;
    gl_Position = vec4(p.x * 2.0 - 1.0, 1.0 - p.y * 2.0, 0.0, 1.0);
}
#endif

#ifdef FRAGMENT
uniform sampler2D u_font;
in vec2 v_uv;
in vec4 v_color;
out vec4 o_color;
void main() { o_color = vec4(v_color.rgb, v_color.a * texture(u_font, v_uv).a); }
#endif
