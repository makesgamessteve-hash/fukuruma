// Atmospheric scattering (CONCEPT 4.4): single scattering of the star's light by the current world's air, marched
// along each view ray: Rayleigh and Mie scattering and absorption, with densities falling off exponentially with
// height. The same model gives the sky from the ground, the shell from space and the haze over distant geometry.
#ifdef FRAGMENT
uniform sampler2D u_scene;
uniform sampler2D u_depth;
uniform mat4 u_inv_view;
uniform float u_top;         // the top of its air
uniform float u_height;      // Rayleigh scale height (Mie: a fifth of it)
uniform vec3 u_rayleigh;     // per metre at the surface
uniform float u_mie;
uniform vec3 u_absorb;
uniform vec3 u_sun_dir;
uniform vec3 u_sun_color;
uniform vec3 u_ground;       // the lit colour of the world's surface where nothing is drawn (beyond the scene)
uniform vec2 u_fog;          // ground fog: extinction per metre at the surface, scale height (metres)
out vec4 o_color;

const int STEPS = 16;
const int LIGHT_STEPS = 4;

vec2 sphere(vec3 o, vec3 d, float r) { // the ray's distances into and out of a sphere about the origin (no hit: x > y)
    float b = dot(o, d), c = dot(o, o) - r * r, h = b * b - c;
    if (h < 0.0) return vec2(1e30, -1e30);
    h = sqrt(h);
    return vec2(-b - h, -b + h);
}

vec3 density(vec3 p) { // Rayleigh, Mie and absorbing densities at a point (relative to the centre)
    float h = max(length(p) - u_radius, 0.0);
    float r = exp(-h / u_height), m = exp(-h / (u_height * 0.2));
    if (u_fog.x > 0.0) m += u_fog.x / max(u_mie, 1e-12) * exp(-h / u_fog.y); // fog: more of the same haze, low down
    return vec3(r, m, r * max(0.0, 1.0 - abs(h - 25000.0) / 15000.0)); // absorption in a layer, like ozone
}

vec3 extinction(vec3 d) { return u_rayleigh * d.x + vec3(u_mie * 1.1) * d.y + u_absorb * d.z; }

void main() {
    vec3 scene = texture(u_scene, v_uv).rgb;
    float depth = texture(u_depth, v_uv).r;
    vec3 view = view_position(v_uv, is_sky(depth) ? u_slice_hi.w : depth);
    vec3 dir = normalize(mat3(u_inv_view) * view);
    vec3 cam = (u_inv_view * vec4(0.0, 0.0, 0.0, 1.0)).xyz - u_centre;
    float scene_dist = is_sky(depth) ? 1e30 : length(view);
    vec2 air = sphere(cam, dir, u_top), ground = sphere(cam, dir, u_radius);
    float t0 = max(air.x, 0.0), t1 = min(air.y, scene_dist);
    if (ground.x > 0.0 && ground.x < t1) { // the world itself blocks the ray
        t1 = ground.x;
        if (is_sky(depth)) scene = u_ground * max(dot(normalize(cam + dir * t1), u_sun_dir), 0.0);
    }
    if (t1 <= t0) {
        o_color = vec4(scene, 1.0);
        return;
    }
    float mu = dot(dir, u_sun_dir);
    float phase_r = 3.0 / (16.0 * PI) * (1.0 + mu * mu);
    const float g = 0.76;
    float phase_m = 3.0 / (8.0 * PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / ((2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
    vec3 depth_view = vec3(0.0), light_r = vec3(0.0), light_m = vec3(0.0);
    for (int i = 0; i < STEPS; i++) { // denser near the eye, where most of the light reaching it is scattered
        float a = float(i) / float(STEPS), b = float(i + 1) / float(STEPS);
        float ta = t0 + (t1 - t0) * a * a, tb = t0 + (t1 - t0) * b * b, ds = tb - ta;
        vec3 p = cam + dir * (0.5 * (ta + tb));
        vec3 d = density(p) * ds;
        depth_view += d;
        vec2 out_air = sphere(p, u_sun_dir, u_top);
        if (sphere(p, u_sun_dir, u_radius).x > 0.0) continue; // the world shadows this point
        float ls = out_air.y / float(LIGHT_STEPS);
        vec3 depth_light = vec3(0.0);
        for (int j = 0; j < LIGHT_STEPS; j++) depth_light += density(p + u_sun_dir * ((float(j) + 0.5) * ls)) * ls;
        vec3 tau = extinction(depth_view + depth_light);
        vec3 att = exp(-tau) * cloud_shadow(p, u_sun_dir); // under broken cloud: shafts of light through the haze
        light_r += att * d.x;
        light_m += att * d.y;
    }
    vec3 inscatter = (light_r * u_rayleigh * phase_r + light_m * u_mie * phase_m) * u_sun_color;
    vec3 transmit = exp(-extinction(depth_view));
    vec3 seen = scene * transmit + inscatter;
    // Clouds: marched along the ray through their layer, in front of what is drawn; lit by the star through the cloud
    // above each sample (forward-scattering, with a little light from the sky), seen through half the air's haze.
    if (u_cloud_steps > 0) {
        vec2 outer = sphere(cam, dir, u_radius + u_cloud_layer.y), inner = sphere(cam, dir, u_radius + u_cloud_layer.x);
        float hc = length(cam) - u_radius, a, b;
        if (hc < u_cloud_layer.x) { // below the layer: from the layer's bottom to its top
            a = inner.y;
            b = outer.y;
        } else { // in it, or above: to where the ray leaves the layer, down or out
            a = hc < u_cloud_layer.y ? 0.0 : outer.x;
            b = inner.x > 0.0 ? inner.x : outer.y;
        }
        a = max(a, 0.0); // (from above, the layer's far side can lie behind the camera)
        if (ground.x > 0.0) b = min(b, ground.x);
        b = min(min(b, scene_dist), a + 30000.0);
        if (b > a && a < 1e29) {
            float ds = (b - a) / float(u_cloud_steps), t = 1.0;
            // a different start in each pixel (interleaved gradient noise): banding becomes fine grain
            float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
            float forward = (1.0 - 0.36) / (4.0 * PI * pow(1.36 - 1.2 * mu, 1.5));
            vec3 lit = vec3(0.0);
            for (int i = 0; i < 64; i++) {
                if (i >= u_cloud_steps || t < 0.02) break;
                float along = a + (float(i) + jitter) * ds;
                vec3 p = cam + dir * along;
                float d = cloud_density(p) * (1.0 - smoothstep(18000.0, 30000.0, along)); // thinning into the distance
                if (d <= 0.0) continue;
                vec3 light = u_sun_color * (cloud_shadow(p, u_sun_dir) * (forward + 0.08) + 0.05);
                lit += t * light * (1.0 - exp(-d * ds));
                t *= exp(-d * ds);
            }
            seen = seen * t + lit * sqrt(transmit);
        }
    }
    o_color = vec4(seen, 1.0);
}
#endif
