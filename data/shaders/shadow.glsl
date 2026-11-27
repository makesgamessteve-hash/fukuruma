// Depth only, from the star's point of view.
#ifdef VERTEX
in vec3 a_position;
uniform mat4 u_model;
uniform mat4 u_view_proj;
out vec3 v_world;
void main() {
    vec4 world = u_model * vec4(instance_point((skin_matrix() * vec4(a_position, 1.0)).xyz), 1.0);
    v_world = world.xyz;
    gl_Position = u_view_proj * world;
}
#endif

#ifdef FRAGMENT
in vec3 v_world;
void main() {
    if (u_ndigs > 0 && dug(v_world)) discard; // a dug hole lets the light in
}
#endif
