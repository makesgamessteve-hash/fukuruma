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
vec3 linear_to_srgb(vec3 c) { return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)); }

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

#if defined(SCENE_MESH) && defined(VERTEX)
in vec4 a_joints;
in vec4 a_weights;
uniform highp sampler2D u_bones; // one row of four texels (the matrix columns) per bone
uniform int u_bone_offset;       // the draw's first bone, -1: not skinned
mat4 bone(float joint) {
    int row = u_bone_offset + int(joint);
    return mat4(texelFetch(u_bones, ivec2(0, row), 0), texelFetch(u_bones, ivec2(1, row), 0),
                texelFetch(u_bones, ivec2(2, row), 0), texelFetch(u_bones, ivec2(3, row), 0));
}
mat4 skin_matrix() { // bind pose to model space, blended from up to four bones
    if (u_bone_offset < 0) return mat4(1.0);
    return a_weights.x * bone(a_joints.x) + a_weights.y * bone(a_joints.y) + a_weights.z * bone(a_joints.z) +
           a_weights.w * bone(a_joints.w);
}

// Instances (gfx.h fk_instances): one mesh drawn many times, each scaled, turned about y, bent by the wind (more the
// higher a point is) and moved.
in vec4 a_inst0;      // position (draw axes) and scale
in vec4 a_inst1;      // yaw, brightness, sway phase, sway amount
uniform int u_instanced;
uniform vec4 u_wind;  // x, z: wind direction times strength; w: time (seconds)
vec3 instance_turn(vec3 v) {
    if (u_instanced == 0) return v;
    float c = cos(a_inst1.x), s = sin(a_inst1.x);
    return vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}
vec3 instance_point(vec3 p) {
    if (u_instanced == 0) return p;
    vec3 q = instance_turn(p) * a_inst0.w;
    float gust = 0.65 + 0.35 * sin(u_wind.w * 1.9 + a_inst1.z) * sin(u_wind.w * 0.7 + a_inst1.z * 1.3);
    q.xz += u_wind.xy * (a_inst1.w * q.y * q.y * gust);
    return q + a_inst0.xyz;
}
#endif

#ifdef FRAGMENT
// Depth slices (gfx/frame.h): each slice writes its own part of the depth buffer, from u_slice_lo[i] to
// u_slice_hi[i], with its own projection. These turn a depth value back into a view-space position.
uniform vec4 u_slice_lo;
uniform vec4 u_slice_hi;
uniform mat4 u_slice_inv_proj[4];

bool is_sky(float d) { return d >= u_slice_hi.w; } // nothing drawn: beyond the last slice

int depth_slice(float d) { return d < u_slice_hi.x ? 0 : d < u_slice_hi.y ? 1 : d < u_slice_hi.z ? 2 : 3; }

vec3 view_position(vec2 uv, float d) {
    int i = depth_slice(d);
    float z = clamp((d - u_slice_lo[i]) / (u_slice_hi[i] - u_slice_lo[i]), 0.0, 1.0); // the sky (1) sits on the far plane
    vec4 p = u_slice_inv_proj[i] * vec4(vec3(uv, z) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}
#endif
