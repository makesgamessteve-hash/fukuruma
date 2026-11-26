/* 4x4 float matrices, column-major (the OpenGL layout). */
#pragma once
#include <stdbool.h>

void fk_mat4_identity(float out[16]);
void fk_mat4_mul(float out[16], const float a[16], const float b[16]); /* out = a * b; out may alias a or b */
bool fk_mat4_inverse(float out[16], const float m[16]);                /* false for a singular matrix */
void fk_mat4_ortho(float out[16], float l, float r, float b, float t, float n, float f);
void fk_mat4_look(float out[16], const float eye[3], const float dir[3], const float up[3]); /* a view matrix */
void fk_mat4_point(const float m[16], const float p[3], float out[3]); /* transform with perspective divide */
/* translation * rotation (unit quaternion x, y, z, w) * scale */
void fk_mat4_trs(float out[16], const float t[3], const float q[4], const float s[3]);
