// Depth only, from the star's point of view.
#ifdef VERTEX
in vec3 a_position;
uniform mat4 u_model;
uniform mat4 u_view_proj;
void main() { gl_Position = u_view_proj * (u_model * vec4(instance_point((skin_matrix() * vec4(a_position, 1.0)).xyz), 1.0)); }
#endif

#ifdef FRAGMENT
void main() {}
#endif
