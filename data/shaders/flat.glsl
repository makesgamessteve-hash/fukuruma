// Unlit vertex colours: the overlay (UI, touch controls). The engine prepends #version and defines VERTEX or FRAGMENT.
#ifdef VERTEX
in vec3 a_position;
in vec3 a_color;
uniform mat4 u_mvp;
out vec3 v_color;

void main() {
    v_color = a_color;
    gl_Position = u_mvp * vec4(a_position, 1.0);
}
#endif

#ifdef FRAGMENT
in vec3 v_color;
out vec4 o_color;

void main() {
    o_color = vec4(v_color, 1.0);
}
#endif
