/* Cascaded shadow maps for the star light: split distances and stable, texel-snapped light matrices. */
#pragma once

#define FK_MAX_CASCADES 4
#define FK_SHADOW_DISTANCE 80.0f /* view distance covered by the cascades */

typedef struct {
    float view_proj[16];
    float split; /* view distance at which this cascade ends */
    float texel; /* world size of one shadow-map texel */
} fk_cascade;

/* View distance where cascade i (0-based) of count ends (practical split scheme, lambda 0.75). */
float fk_shadow_split(int i, int count, float near, float far);

/* Fits a cascade around the camera frustum slice [d0, d1] (view distances). inv_view_proj: inverse of the
   camera's projection * view; to_light: direction towards the star. */
void fk_shadow_cascade(fk_cascade *out, const float inv_view_proj[16], float near, float far, float d0, float d1,
                       const float to_light[3], int map_size);
