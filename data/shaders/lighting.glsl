// Deferred lighting: star (with cascaded shadows), point lights, sky/ground ambient, emission.
#ifdef FRAGMENT
uniform sampler2D u_base;
uniform sampler2D u_normal;
uniform sampler2D u_emission;
uniform sampler2D u_depth;
uniform sampler2D u_ao;
#if SHADOW_CASCADES > 0
uniform sampler2DArrayShadow u_shadow;
uniform mat4 u_cascade[SHADOW_CASCADES];
#endif
uniform vec4 u_splits;
uniform vec4 u_texels;
uniform mat4 u_inv_view;
uniform mat4 u_view;
uniform vec3 u_camera;
uniform vec3 u_sun_dir;
uniform vec3 u_sun_color;
uniform vec3 u_sun2_dir;   // a second star (binaries), unshadowed
uniform vec3 u_sun2_color;
uniform vec3 u_sky;
uniform vec3 u_ground;
uniform vec3 u_background;
uniform samplerCube u_sky_map; // the stars and the galactic band (black without a sky)
uniform float u_sky_strength;
uniform mat3 u_sky_rotation;  // world directions into the sky's
uniform float u_exposure_bias;
uniform int u_nlights;
#if MAX_LIGHTS > 0
uniform vec4 u_light_pos[MAX_LIGHTS];
uniform vec4 u_light_color[MAX_LIGHTS];
#endif
out vec4 o_color;

float shadow(vec3 world, vec3 n, float view_depth) {
#if SHADOW_CASCADES > 0
    if (view_depth > u_splits[SHADOW_CASCADES - 1]) return 1.0;
    int c = 0;
    for (int i = 0; i < SHADOW_CASCADES - 1; i++)
        if (view_depth > u_splits[i]) c = i + 1;
    vec4 lp = u_cascade[c] * vec4(world + n * u_texels[c] * 1.5, 1.0); // normal offset against acne
    vec3 sc = lp.xyz / lp.w * 0.5 + 0.5;
    float o = 0.75 / float(SHADOW_SIZE), layer = float(c);
    return 0.25 * (texture(u_shadow, vec4(sc.xy + vec2(-o, -o), layer, sc.z)) +
                   texture(u_shadow, vec4(sc.xy + vec2(o, -o), layer, sc.z)) +
                   texture(u_shadow, vec4(sc.xy + vec2(-o, o), layer, sc.z)) +
                   texture(u_shadow, vec4(sc.xy + vec2(o, o), layer, sc.z)));
#else
    return 1.0;
#endif
}

vec3 brdf(vec3 n, vec3 v, vec3 l, vec3 albedo, float rough, float metal) { // GGX, Smith, Schlick; Lambert
    vec3 h = normalize(v + l);
    float nl = max(dot(n, l), 0.0), nv = max(dot(n, v), 1e-4), nh = max(dot(n, h), 0.0), vh = clamp(dot(v, h), 0.0, 1.0); // pow of 1 - vh below 0 is NaN
    float a = rough * rough, a2 = a * a;
    float d = a2 / (PI * pow(nh * nh * (a2 - 1.0) + 1.0, 2.0));
    float k = (rough + 1.0) * (rough + 1.0) / 8.0;
    float g = nv / (nv * (1.0 - k) + k) * nl / (nl * (1.0 - k) + k);
    vec3 f0 = mix(vec3(0.04), albedo, metal);
    vec3 f = f0 + (1.0 - f0) * pow(1.0 - vh, 5.0);
    vec3 spec = d * g * f / max(4.0 * nv * nl, 1e-4);
    vec3 diffuse = (1.0 - f) * (1.0 - metal) * albedo / PI;
    return (diffuse + spec) * nl;
}

void main() {
    float depth = texture(u_depth, v_uv).r;
    vec3 color;
    if (is_sky(depth)) {
        vec4 far = u_slice_inv_proj[1] * vec4(v_uv * 2.0 - 1.0, 1.0, 1.0); // through the pixel, in view space
        vec3 dir = normalize(mat3(u_inv_view) * (far.xyz / far.w));
        color = u_background + texture(u_sky_map, u_sky_rotation * dir).rgb * u_sky_strength;
    } else {
        vec3 world = (u_inv_view * vec4(view_position(v_uv, depth), 1.0)).xyz;
        vec4 base = texture(u_base, v_uv);
        vec3 albedo = srgb_to_linear(base.rgb);
        float metal = base.a;
        vec4 nr = texture(u_normal, v_uv);
        vec3 n = decode_normal(nr.rg);
        float rough = max(nr.b, 0.04);
        vec4 em = texture(u_emission, v_uv);
        vec3 v = normalize(u_camera - world);
        float view_depth = -(u_view * vec4(world, 1.0)).z;

        float sun = shadow(world, n, view_depth) * cloud_shadow(world - u_centre, u_sun_dir);
        if (u_water_on == 1) { // under the sea: less light the deeper, gathered into caustics by the waves
            vec3 rel = world - u_water_centre;
            float below = u_water_radius - length(rel);
            if (below > 0.0) sun *= exp(-below * 0.18) * caustics(rel, u_water_waves.x);
        }
        color = brdf(n, v, u_sun_dir, albedo, rough, metal) * u_sun_color * sun;
        if (dot(u_sun2_color, u_sun2_color) > 0.0) color += brdf(n, v, u_sun2_dir, albedo, rough, metal) * u_sun2_color;
#if MAX_LIGHTS > 0
        for (int i = 0; i < MAX_LIGHTS; i++) {
            if (i >= u_nlights) break;
            vec3 d = u_light_pos[i].xyz - world;
            float dist2 = max(dot(d, d), 1e-4), r = u_light_pos[i].w;
            float window = clamp(1.0 - pow(dist2 / (r * r), 2.0), 0.0, 1.0);
            color += brdf(n, v, d * inversesqrt(dist2), albedo, rough, metal) * u_light_color[i].rgb * window * window / dist2;
        }
#endif
        float ao = texture(u_ao, v_uv).r;
        vec3 f0 = mix(vec3(0.04), albedo, metal);
        vec3 fresnel = f0 + (max(vec3(1.0 - rough), f0) - f0) * pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 5.0);
        vec3 hemisphere = mix(u_ground, u_sky, n.y * 0.5 + 0.5);
        vec3 environment = mix(u_ground, u_sky, reflect(-v, n).y * 0.5 + 0.5);
        color += (hemisphere * albedo * (1.0 - metal) * (1.0 - fresnel) + environment * fresnel * (1.0 - 0.7 * rough)) * ao;
        color += em.rgb * em.a * 16.0;
    }
#ifndef HDR
    const float LDR_EXPOSURE = 4.0; // LDR fallback: no auto exposure, so a typical value for lit scenes
    color = aces(color * LDR_EXPOSURE * u_exposure_bias); // tone-map here, before the 8-bit target
#endif
    o_color = vec4(color, 1.0);
}
#endif
