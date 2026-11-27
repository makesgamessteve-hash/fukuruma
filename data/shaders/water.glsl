// The sea (water spec): where a view ray meets the sea before anything drawn, the water's surface: waves from moving
// swells, the sky and a glint of the star in it (Fresnel), and below it the drawn scene refracted and dimmed by the
// depth of water it is seen through (red light goes first), foam where the water is shallow. From under the surface,
// everything is seen through water. A full-screen pass: the sea reaches the horizon without a mesh.
#ifdef FRAGMENT
uniform sampler2D u_scene;
uniform sampler2D u_depth;
uniform mat4 u_inv_view;
uniform vec3 u_sun_dir;
uniform vec3 u_sun_color;
uniform vec3 u_sky;          // the ambient sky light (linear)
out vec4 o_color;

vec2 hit_sphere(vec3 o, vec3 d, float r) {
    float b = dot(o, d), c = dot(o, o) - r * r, h = b * b - c;
    if (h < 0.0) return vec2(1e30, -1e30);
    h = sqrt(h);
    return vec2(-b - h, -b + h);
}

// The surface's normal at p (relative to the centre): four swells in the plane of the surface, fading with distance.
vec3 waves(vec3 p, vec3 up, float distance) {
    vec3 east = normalize(cross(up, vec3(0.0, 0.0, 1.0) + up.zxy * 0.01)), north = cross(east, up);
    vec2 q = vec2(dot(p, east), dot(p, north));
    float t = u_water_waves.x, amp = u_water_waves.y / (1.0 + distance * 0.004);
    vec2 slope = vec2(0.0);
    const vec4 W[6] = vec4[6](vec4(0.8, 0.6, 0.35, 1.1), vec4(-0.53, 0.85, 0.61, 1.6), vec4(0.17, -0.99, 1.13, 2.2),
                              vec4(-0.93, -0.37, 1.87, 2.9), vec4(0.62, -0.78, 2.71, 3.6), vec4(-0.29, 0.96, 3.93, 4.4));
    for (int i = 0; i < 6; i++) { // direction (x, y), wave number, angular speed
        float phase = dot(W[i].xy, q) * W[i].z - t * W[i].w;
        float fade = 1.0 - smoothstep(0.0, 1.0, distance * W[i].z * 0.004); // short waves go first with distance
        slope += W[i].xy * (W[i].z * amp * 0.22 * cos(phase)) * fade / (1.0 + 0.6 * float(i));
    }
    return normalize(up - east * slope.x - north * slope.y);
}

void main() {
    vec3 scene = texture(u_scene, v_uv).rgb;
    float depth = texture(u_depth, v_uv).r;
    bool sky = is_sky(depth);
    vec3 view = view_position(v_uv, sky ? u_slice_hi.w : depth);
    vec3 dir = normalize(mat3(u_inv_view) * view);
    vec3 cam = (u_inv_view * vec4(0.0, 0.0, 0.0, 1.0)).xyz - u_water_centre;
    float scene_dist = sky ? 1e30 : length(view);
    float lit = max(dot(normalize(cam), u_sun_dir), 0.0);
    vec3 body = u_water_shallow * (u_sun_color * (0.05 + 0.2 * lit) + u_sky); // the light scattered inside the water
    if (length(cam) < u_water_radius) { // under the surface: the scene through water
        float through = min(scene_dist, 400.0);
        vec3 absorb = exp(-through * vec3(0.3, 0.06, 0.045));
        o_color = vec4(scene * absorb + body * 1.5 * (1.0 - absorb), 1.0);
        return;
    }
    vec2 hit = hit_sphere(cam, dir, u_water_radius);
    if (hit.x <= 0.0 || hit.x >= scene_dist) {
        o_color = vec4(scene, 1.0);
        return;
    }
    vec3 p = cam + dir * hit.x, up = normalize(p);
    vec3 n = waves(p, up, hit.x);
    float thickness = sky ? 1e4 : scene_dist - hit.x; // how much water the eye looks through to the floor
    // refraction: the drawn floor, shifted by the waves (unless that would show something above the water)
    vec3 tilt = n - up; // the waves' tilt across the screen (the view's right and up axes)
    vec2 shift = vec2(dot(tilt, normalize(mat3(u_inv_view)[0])), dot(tilt, normalize(mat3(u_inv_view)[1]))) * 0.04
          * min(thickness, 4.0) / (1.0 + hit.x * 0.05);
    vec2 uv = v_uv + shift;
    float d2 = texture(u_depth, uv).r;
    vec3 under = (!is_sky(d2) && length(view_position(uv, d2)) > hit.x) ? texture(u_scene, uv).rgb : scene;
    vec3 absorb = exp(-thickness * vec3(0.6, 0.16, 0.12));
    vec3 tint = mix(u_water_shallow, u_water_deep, 1.0 - exp(-thickness * 0.15));
    vec3 refracted = under * absorb * mix(vec3(1.0), tint * 2.2, min(thickness * 0.5, 0.7)) + tint * body * 3.0 * (1.0 - absorb.g);
    // reflection: the sky (brighter towards the horizon) and the star's glint
    vec3 r = reflect(dir, n);
    float horizon = 1.0 - max(dot(r, up), 0.0);
    // (the sky's own light, roughly: what the air scatters of the star, bluer overhead and brighter at the horizon)
    vec3 sky_light = (u_sky + u_sun_color * vec3(0.05, 0.08, 0.13)) * (1.0 + 1.6 * horizon * horizon);
    float glint = pow(max(dot(r, u_sun_dir), 0.0), 600.0) * 50.0 + pow(max(dot(r, u_sun_dir), 0.0), 90.0) * 0.12;
    float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(n, -dir), 0.0), 5.0);
    vec3 color = mix(refracted, sky_light, fresnel) + u_sun_color * glint * (1.0 - fresnel * 0.5);
    // foam along the shore, broken up by the waves
    float foam = (1.0 - smoothstep(0.0, 0.8, thickness)) * (0.6 + 0.4 * sin(dot(p, vec3(3.1, 2.7, 1.9)) + u_water_waves.x * 2.0));
    color = mix(color, (u_sun_color * (0.3 + 0.6 * lit) + u_sky) * 0.9, clamp(foam, 0.0, 1.0) * 0.85);
    o_color = vec4(color, 1.0);
}
#endif
