// Screen-space ambient occlusion: a normal-oriented hemisphere of depth samples.
#ifdef FRAGMENT
uniform sampler2D u_depth;
uniform sampler2D u_normal;
uniform mat4 u_inv_proj;
uniform mat4 u_proj;
uniform mat4 u_view;
out vec4 o_color;

const float RADIUS = 0.6;

vec3 view_position(vec2 uv) {
    vec4 p = u_inv_proj * vec4(vec3(uv, texture(u_depth, uv).r) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}

void main() {
    if (texture(u_depth, v_uv).r >= 1.0) {
        o_color = vec4(1.0);
        return;
    }
    vec3 p = view_position(v_uv);
    vec3 n = normalize(mat3(u_view) * decode_normal(texture(u_normal, v_uv).rg));
    vec3 t = normalize(cross(n, abs(n.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
    vec3 b = cross(n, t);
    float spin = float(fk_hash(uvec2(gl_FragCoord.xy)) & 1023u) / 1024.0 * 2.0 * PI;
    float occlusion = 0.0;
    for (int i = 0; i < AO_SAMPLES; i++) {
        float f = (float(i) + 0.5) / float(AO_SAMPLES);
        float phi = float(i) * 2.399963 + spin; // golden-angle spiral
        float r = sqrt(f);
        vec3 dir = t * (cos(phi) * r) + b * (sin(phi) * r) + n * sqrt(1.0 - f);
        vec3 s = p + dir * RADIUS * mix(0.2, 1.0, f * f);
        vec4 q = u_proj * vec4(s, 1.0);
        float scene_z = view_position(q.xy / q.w * 0.5 + 0.5).z;
        float range = smoothstep(0.0, 1.0, RADIUS / max(abs(p.z - scene_z), 1e-4));
        occlusion += (scene_z >= s.z + 0.02 ? 1.0 : 0.0) * range;
    }
    o_color = vec4(1.0 - occlusion / float(max(AO_SAMPLES, 1)));
}
#endif
