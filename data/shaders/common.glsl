// Shared by every shader. The engine prepends #version, precision, the quality #defines and VERTEX or FRAGMENT.
#if defined(FULLSCREEN) && defined(VERTEX)
out vec2 v_uv;
void main() { // one triangle that covers the screen, made from the vertex number
    vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
    v_uv = p;
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
#endif
#if defined(FULLSCREEN) && defined(FRAGMENT)
in vec2 v_uv;
#endif

const float PI = 3.14159265;

vec3 srgb_to_linear(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }

vec3 aces(vec3 x) { // Narkowicz's fit of the ACES filmic tone curve
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

vec2 sign_not_zero(vec2 v) { return vec2(v.x >= 0.0 ? 1.0 : -1.0, v.y >= 0.0 ? 1.0 : -1.0); }

vec2 encode_normal(vec3 n) { // octahedral mapping into 0..1
    n /= abs(n.x) + abs(n.y) + abs(n.z);
    vec2 e = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * sign_not_zero(n.xy);
    return e * 0.5 + 0.5;
}

vec3 decode_normal(vec2 e) {
    e = e * 2.0 - 1.0;
    vec3 n = vec3(e, 1.0 - abs(e.x) - abs(e.y));
    if (n.z < 0.0) n.xy = (1.0 - abs(n.yx)) * sign_not_zero(n.xy);
    return normalize(n);
}

uint fk_hash(uvec2 p) { // integer hash: the same noise on every GPU
    uint h = p.x * 1664525u + p.y * 1013904223u;
    h ^= h >> 16u;
    h *= 2246822519u;
    h ^= h >> 13u;
    h *= 3266489917u;
    return h ^ (h >> 16u);
}
