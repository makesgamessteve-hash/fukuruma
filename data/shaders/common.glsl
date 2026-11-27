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

// Clouds (volumetric-clouds-and-fog spec): a layer of the world's air between two heights, whose density is value
// noise shaped by the cover and by the height within the layer; it drifts with the wind (u_cloud_offset).
uniform int u_cloud_steps;    // 0: no clouds
uniform vec3 u_centre;        // the world's centre (camera-relative world space)
uniform float u_radius;       // its surface
uniform vec4 u_cloud_layer;        // bottom, top (metres above the surface), cover 0..1, density per metre
uniform vec3 u_cloud_offset;  // the wind's drift (metres)
float cloud_lattice(vec3 c) {
    uvec3 q = uvec3(ivec3(c) + 32768);
    uint h = q.x * 73856093u ^ q.y * 19349663u ^ q.z * 83492791u;
    h = (h ^ (h >> 13u)) * 1274126177u;
    return float(h >> 16u) / 65535.0;
}
float cloud_noise(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(cloud_lattice(i), cloud_lattice(i + vec3(1, 0, 0)), f.x),
                   mix(cloud_lattice(i + vec3(0, 1, 0)), cloud_lattice(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(cloud_lattice(i + vec3(0, 0, 1)), cloud_lattice(i + vec3(1, 0, 1)), f.x),
                   mix(cloud_lattice(i + vec3(0, 1, 1)), cloud_lattice(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
// Cloud density (per metre) at p, relative to the world's centre.
float cloud_density(vec3 p) {
    float h = length(p) - u_radius, t = (h - u_cloud_layer.x) / (u_cloud_layer.y - u_cloud_layer.x);
    if (t <= 0.0 || t >= 1.0) return 0.0;
    vec3 q = (p + u_cloud_offset) / 1400.0;
    float n = cloud_noise(q) * 0.55 + cloud_noise(q * 2.7) * 0.3 + cloud_noise(q * 7.3) * 0.15;
    float shape = 4.0 * t * (1.0 - t); // round tops and bottoms
    return max(0.0, n * shape - (1.0 - u_cloud_layer.z) * 0.75) * 4.0 * u_cloud_layer.w;
}
// How much of the star's light gets through the clouds to p (relative to the centre), along sun.
float cloud_shadow(vec3 p, vec3 sun) {
    if (u_cloud_steps == 0) return 1.0;
    float depth = 0.0, ds = (u_cloud_layer.y - u_cloud_layer.x) / 4.0;
    vec3 up = normalize(p);
    float h = length(p) - u_radius, along = max(dot(up, sun), 0.05);
    float start = max(u_cloud_layer.x - h, 0.0) / along; // to the bottom of the layer, along the sun
    for (int i = 0; i < 4; i++) depth += cloud_density(p + sun * (start + (float(i) + 0.5) * ds / along)) * ds / along;
    return exp(-depth);
}

// The sea (water spec): a sphere at sea level about the world's centre.
uniform int u_water_on;
uniform vec3 u_water_centre;   // camera-relative world space, like the scene
uniform float u_water_radius;
uniform vec3 u_water_deep, u_water_shallow; // linear colours
uniform vec2 u_water_waves;    // time (seconds), wave height (metres)
// Bright threads of light that the waves focus on the sea floor (relative position, time).
float caustics(vec3 p, float t) {
    vec2 q = p.xz * 0.9 + p.y * 0.3;
    float a = abs(sin(q.x + sin(q.y * 1.3 + t * 0.9)) * sin(q.y * 1.1 + sin(q.x * 0.7 - t * 0.7)));
    float b = abs(sin(q.x * 1.7 - t * 0.5 + sin(q.y * 2.1)) * sin(q.y * 1.9 + t * 0.6));
    return 0.35 + 1.4 * pow(1.0 - min(a, b), 6.0);
}

// Dug ground (voxel-terrain spec): terrain pixels inside a dig are left out (its walls are their own mesh).
uniform int u_ndigs;
uniform vec4 u_digs[16]; // draw axes: centre and radius
bool dug(vec3 world) {
    for (int i = 0; i < 16; i++) {
        if (i >= u_ndigs) break;
        vec3 d = world - u_digs[i].xyz;
        if (dot(d, d) < u_digs[i].w * u_digs[i].w) return true;
    }
    return false;
}

int depth_slice(float d) { return d < u_slice_hi.x ? 0 : d < u_slice_hi.y ? 1 : d < u_slice_hi.z ? 2 : 3; }

vec3 view_position(vec2 uv, float d) {
    int i = depth_slice(d);
    float z = clamp((d - u_slice_lo[i]) / (u_slice_hi[i] - u_slice_lo[i]), 0.0, 1.0); // the sky (1) sits on the far plane
    vec4 p = u_slice_inv_proj[i] * vec4(vec3(uv, z) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}
#endif
