/* Poses of glTF models: sampling clips, blending, additive layers, model-space and skin matrices. Plain C. */
#pragma once
#include "assets/model.h"

typedef struct {
    float t[3], r[4], s[3]; /* translation, rotation (x, y, z, w), scale: the node's local transform */
} fk_trs;

/* pose: one fk_trs per node of the model. */
void fk_pose_rest(const fk_model *m, fk_trs *pose);
/* Samples the clip at time (clamped to 0..duration) into the nodes it animates; other nodes are kept. */
void fk_clip_sample(const fk_model *m, int clip, float time, fk_trs *pose);
/* out = a blended towards b by w (0: a, 1: b) for n nodes; out may alias a or b. */
void fk_pose_blend(const fk_trs *a, const fk_trs *b, float w, fk_trs *out, int n);
/* Adds the difference between layer and the rest pose, times w, to pose (additive layers: breathing, recoil). */
void fk_pose_add(const fk_model *m, fk_trs *pose, const fk_trs *layer, float w);
/* Model-space matrix of every node (16 floats each). */
void fk_pose_globals(const fk_model *m, const fk_trs *pose, float *globals);
