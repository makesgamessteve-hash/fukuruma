#include "anim/anim.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "core/mat4.h"

void fk_pose_rest(const fk_model *m, fk_trs *pose) {
    for (int i = 0; i < m->node_count; i++) {
        memcpy(pose[i].t, m->nodes[i].translation, sizeof pose[i].t);
        memcpy(pose[i].r, m->nodes[i].rotation, sizeof pose[i].r);
        memcpy(pose[i].s, m->nodes[i].scale, sizeof pose[i].s);
    }
}

static void normalize4(float q[4]) {
    float len = sqrtf(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]);
    if (len > 0)
        for (int k = 0; k < 4; k++) q[k] /= len;
    else q[3] = 1;
}

/* Shortest-path normalised lerp of unit quaternions. */
static void nlerp(const float a[4], const float b[4], float w, float out[4]) {
    float sign = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3] < 0 ? -1.0f : 1.0f;
    for (int k = 0; k < 4; k++) out[k] = a[k] + (sign * b[k] - a[k]) * w;
    normalize4(out);
}

static void slerp(const float a[4], const float b[4], float w, float out[4]) {
    float d = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3], sign = d < 0 ? -1.0f : 1.0f;
    d = fabsf(d);
    if (d > 0.9995f) { /* nearly equal: nlerp is exact enough and avoids dividing by sin(0) */
        nlerp(a, b, w, out);
        return;
    }
    float theta = acosf(d), sa = sinf((1 - w) * theta) / sinf(theta), sb = sign * sinf(w * theta) / sinf(theta);
    for (int k = 0; k < 4; k++) out[k] = a[k] * sa + b[k] * sb;
    normalize4(out);
}

static void sample_channel(const fk_channel *c, float time, float *out) {
    int comps = c->path == FK_PATH_ROTATION ? 4 : 3, stride = c->interpolation == FK_INTERP_CUBIC ? 3 * comps : comps;
    int value = c->interpolation == FK_INTERP_CUBIC ? comps : 0; /* offset of the value within a key */
    int last = c->count - 1;
    if (time <= c->times[0] || last == 0) {
        memcpy(out, &c->values[value], (size_t)comps * sizeof(float));
        return;
    }
    if (time >= c->times[last]) {
        memcpy(out, &c->values[last * stride + value], (size_t)comps * sizeof(float));
        return;
    }
    int lo = 0, hi = last; /* times[lo] <= time < times[hi] */
    while (hi - lo > 1) {
        int mid = (lo + hi) / 2;
        if (c->times[mid] <= time) lo = mid;
        else hi = mid;
    }
    float dt = c->times[hi] - c->times[lo], u = (time - c->times[lo]) / dt;
    const float *a = &c->values[lo * stride], *b = &c->values[hi * stride];
    if (c->interpolation == FK_INTERP_STEP) {
        memcpy(out, a, (size_t)comps * sizeof(float));
    } else if (c->interpolation == FK_INTERP_CUBIC) { /* Hermite spline: value, out-tangent of a, in-tangent of b */
        float u2 = u * u, u3 = u2 * u;
        float h00 = 2 * u3 - 3 * u2 + 1, h10 = u3 - 2 * u2 + u, h01 = -2 * u3 + 3 * u2, h11 = u3 - u2;
        for (int k = 0; k < comps; k++)
            out[k] = h00 * a[comps + k] + h10 * dt * a[2 * comps + k] + h01 * b[comps + k] + h11 * dt * b[k];
        if (comps == 4) normalize4(out);
    } else if (comps == 4) {
        slerp(a, b, u, out);
    } else {
        for (int k = 0; k < comps; k++) out[k] = a[k] + (b[k] - a[k]) * u;
    }
}

void fk_clip_sample(const fk_model *m, int clip, float time, fk_trs *pose) {
    const fk_clip *c = &m->clips[clip];
    for (int i = 0; i < c->channel_count; i++) {
        const fk_channel *ch = &c->channels[i];
        fk_trs *n = &pose[ch->node];
        sample_channel(ch, time, ch->path == FK_PATH_TRANSLATION ? n->t : ch->path == FK_PATH_ROTATION ? n->r : n->s);
    }
}

void fk_pose_blend(const fk_trs *a, const fk_trs *b, float w, fk_trs *out, int n) {
    for (int i = 0; i < n; i++) {
        fk_trs r;
        for (int k = 0; k < 3; k++) {
            r.t[k] = a[i].t[k] + (b[i].t[k] - a[i].t[k]) * w;
            r.s[k] = a[i].s[k] + (b[i].s[k] - a[i].s[k]) * w;
        }
        nlerp(a[i].r, b[i].r, w, r.r);
        out[i] = r;
    }
}

static void quat_mul(const float a[4], const float b[4], float out[4]) {
    float r[4] = {a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1], a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
                  a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3], a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2]};
    memcpy(out, r, sizeof r);
}

void fk_pose_add(const fk_model *m, fk_trs *pose, const fk_trs *layer, float w) {
    static const float identity[4] = {0, 0, 0, 1};
    for (int i = 0; i < m->node_count; i++) {
        const fk_node *rest = &m->nodes[i];
        float inv[4] = {-rest->rotation[0], -rest->rotation[1], -rest->rotation[2], rest->rotation[3]}, delta[4], part[4];
        quat_mul(inv, layer[i].r, delta); /* the layer's rotation relative to the rest pose */
        nlerp(identity, delta, w, part);
        quat_mul(pose[i].r, part, pose[i].r);
        for (int k = 0; k < 3; k++) {
            pose[i].t[k] += (layer[i].t[k] - rest->translation[k]) * w;
            float ratio = rest->scale[k] != 0 ? layer[i].s[k] / rest->scale[k] : 1;
            pose[i].s[k] *= 1 + (ratio - 1) * w;
        }
    }
}

static void global(const fk_model *m, const fk_trs *pose, float *globals, char *done, int i) {
    if (done[i]) return;
    float local[16];
    fk_mat4_trs(local, pose[i].t, pose[i].r, pose[i].s);
    int p = m->nodes[i].parent;
    if (p >= 0) {
        global(m, pose, globals, done, p);
        fk_mat4_mul(&globals[i * 16], &globals[p * 16], local);
    } else {
        memcpy(&globals[i * 16], local, sizeof local);
    }
    done[i] = 1;
}

void fk_pose_globals(const fk_model *m, const fk_trs *pose, float *globals) {
    char stack_done[256], *done = m->node_count <= 256 ? stack_done : calloc((size_t)m->node_count, 1);
    if (!done) abort(); /* out of memory while animating: nothing sensible to continue with */
    memset(done, 0, (size_t)m->node_count);
    for (int i = 0; i < m->node_count; i++) global(m, pose, globals, done, i);
    if (done != stack_done) free(done);
}
