#include "gfx/shadow.h"

#include <math.h>

#include "core/mat4.h"

float fk_shadow_split(int i, int count, float near, float far) {
    float f = fminf(far, FK_SHADOW_DISTANCE), t = (float)(i + 1) / (float)count;
    return 0.75f * near * powf(f / near, t) + 0.25f * (near + (f - near) * t);
}

void fk_shadow_cascade(fk_cascade *out, const float inv_view_proj[16], float near, float far, float d0, float d1,
                       const float to_light[3], int map_size) {
    /* The slice's corners lie on the lines from the near-plane to the far-plane corners. */
    float t0 = (d0 - near) / (far - near), t1 = (d1 - near) / (far - near), corners[8][3], center[3] = {0, 0, 0};
    for (int i = 0; i < 4; i++) {
        float ndc_near[3] = {(i & 1) ? 1.0f : -1.0f, (i & 2) ? 1.0f : -1.0f, -1.0f}, a[3], b[3];
        float ndc_far[3] = {ndc_near[0], ndc_near[1], 1.0f};
        fk_mat4_point(inv_view_proj, ndc_near, a);
        fk_mat4_point(inv_view_proj, ndc_far, b);
        for (int k = 0; k < 3; k++) {
            corners[i][k] = a[k] + (b[k] - a[k]) * t0;
            corners[i + 4][k] = a[k] + (b[k] - a[k]) * t1;
        }
    }
    for (int i = 0; i < 8; i++)
        for (int k = 0; k < 3; k++) center[k] += corners[i][k] / 8.0f;
    float radius = 0;
    for (int i = 0; i < 8; i++) {
        float dx = corners[i][0] - center[0], dy = corners[i][1] - center[1], dz = corners[i][2] - center[2];
        radius = fmaxf(radius, sqrtf(dx * dx + dy * dy + dz * dz));
    }
    radius = ceilf(radius * 16.0f) / 16.0f; /* the same size every frame, independent of camera rotation */
    float texel = 2.0f * radius / (float)map_size;

    /* Light view at the origin: the orientation never changes with the camera, only the bounds move,
       in whole texels, so shadow edges do not shimmer. */
    float dir[3] = {-to_light[0], -to_light[1], -to_light[2]}, up[3] = {0, 1, 0}, eye[3] = {0, 0, 0}, view[16], c[3];
    if (fabsf(to_light[1]) > 0.99f) up[0] = 1, up[1] = 0;
    fk_mat4_look(view, eye, dir, up);
    fk_mat4_point(view, center, c);
    for (int k = 0; k < 3; k++) c[k] = floorf(c[k] / texel) * texel; /* z too, so the depth range is just as stable */
    float proj[16];
    fk_mat4_ortho(proj, c[0] - radius, c[0] + radius, c[1] - radius, c[1] + radius, -c[2] - radius - FK_SHADOW_DISTANCE,
                  -c[2] + radius);
    fk_mat4_mul(out->view_proj, proj, view);
    out->split = d1;
    out->texel = texel;
}
