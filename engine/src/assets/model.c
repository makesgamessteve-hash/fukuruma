#include "assets/model.h"

#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "assets/image.h"
#include "assets/vfs.h"
#include "cgltf.h"
#include "core/mat4.h"
#include "gfx/frame.h"
#include "platform/platform.h"

#define FK_MAX_MODEL_VERTICES (1 << 20)
#define FK_MAX_MODEL_NODES 4096

static bool fail(char *error, size_t size, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(error, size, fmt, ap);
    va_end(ap);
    return false;
}

/* Files a model refers to must stay inside data/ (models come from mods too). */
static bool inside_data(const char *path) {
    return path[0] != '/' && !strstr(path, "..") && !strchr(path, ':') && !strchr(path, '\\');
}

static cgltf_result read_file(const struct cgltf_memory_options *memory, const struct cgltf_file_options *file, const char *path,
                              cgltf_size *size, void **data) {
    (void)memory;
    (void)file;
    if (!inside_data(path)) return cgltf_result_io_error;
    size_t n;
    void *p = fk_vfs_read(path, &n);
    if (!p) return cgltf_result_file_not_found;
    *size = n;
    *data = p;
    return cgltf_result_success;
}

static void release_file(const struct cgltf_memory_options *memory, const struct cgltf_file_options *file, void *data) {
    (void)memory;
    (void)file;
    fk_platform_free(data);
}

static void copy_name(char *dst, const char *src) { snprintf(dst, FK_NAME_SIZE, "%s", src ? src : ""); }

/* Rotation of a matrix whose columns are orthogonal (scale removed) as a quaternion. */
static void matrix_to_quat(const float m[16], const float s[3], float q[4]) {
    float r[9];
    for (int c = 0; c < 3; c++)
        for (int k = 0; k < 3; k++) r[c * 3 + k] = s[c] != 0 ? m[c * 4 + k] / s[c] : 0;
    float trace = r[0] + r[4] + r[8];
    if (trace > 0) {
        float t = sqrtf(trace + 1.0f) * 2;
        q[3] = 0.25f * t, q[0] = (r[5] - r[7]) / t, q[1] = (r[6] - r[2]) / t, q[2] = (r[1] - r[3]) / t;
    } else if (r[0] > r[4] && r[0] > r[8]) {
        float t = sqrtf(1.0f + r[0] - r[4] - r[8]) * 2;
        q[3] = (r[5] - r[7]) / t, q[0] = 0.25f * t, q[1] = (r[3] + r[1]) / t, q[2] = (r[6] + r[2]) / t;
    } else if (r[4] > r[8]) {
        float t = sqrtf(1.0f + r[4] - r[0] - r[8]) * 2;
        q[3] = (r[6] - r[2]) / t, q[0] = (r[3] + r[1]) / t, q[1] = 0.25f * t, q[2] = (r[7] + r[5]) / t;
    } else {
        float t = sqrtf(1.0f + r[8] - r[0] - r[4]) * 2;
        q[3] = (r[1] - r[3]) / t, q[0] = (r[6] + r[2]) / t, q[1] = (r[7] + r[5]) / t, q[2] = 0.25f * t;
    }
}

static int texture_image(const cgltf_data *data, const cgltf_texture_view *view) {
    return view->texture && view->texture->image ? (int)(view->texture->image - data->images) : -1;
}

static bool load_image(fk_model_image *img, const cgltf_image *im, const cgltf_options *options, const char *rel, char *error,
                       size_t es) {
    const uint8_t *bytes = NULL;
    size_t n = 0;
    void *owned = NULL;
    bool vfs = false;
    if (im->buffer_view && im->buffer_view->buffer->data) {
        bytes = (const uint8_t *)im->buffer_view->buffer->data + im->buffer_view->offset;
        n = im->buffer_view->size;
    } else if (im->uri && strncmp(im->uri, "data:", 5) == 0) {
        const char *b64 = strchr(im->uri, ',');
        if (b64) {
            size_t len = strlen(++b64);
            while (len && b64[len - 1] == '=') len--;
            n = len * 3 / 4;
            if (cgltf_load_buffer_base64(options, n, b64, &owned) == cgltf_result_success) bytes = owned;
        }
    } else if (im->uri) {
        char path[1024];
        const char *slash = strrchr(rel, '/');
        int dir = slash ? (int)(slash - rel + 1) : 0;
        snprintf(path, sizeof path, "%.*s%s", dir, rel, im->uri);
        bytes = owned = inside_data(path) ? fk_vfs_read(path, &n) : NULL;
        vfs = true;
    }
    if (!bytes) return fail(error, es, "%s: image '%s' cannot be read", rel, im->uri ? im->uri : im->name ? im->name : "?");
    const char *why = NULL;
    img->rgba = fk_image_decode(bytes, n, &img->width, &img->height, &why);
    if (vfs) fk_platform_free(owned);
    else free(owned);
    if (!img->rgba) return fail(error, es, "%s: image '%s': %s", rel, im->uri ? im->uri : im->name ? im->name : "?", why);
    return true;
}

static bool read_floats(const cgltf_accessor *a, cgltf_size i, float *out, cgltf_size n) {
    return cgltf_accessor_read_float(a, i, out, n);
}

static bool convert_primitive(fk_primitive *p, const cgltf_primitive *prim, const cgltf_data *data, bool needs_tangents,
                              const char *rel, char *error, size_t es) {
    if (prim->type != cgltf_primitive_type_triangles) return fail(error, es, "%s: only triangle meshes are supported", rel);
    const cgltf_accessor *pos = NULL, *nor = NULL, *uv = NULL, *tan = NULL, *col = NULL, *joi = NULL, *wei = NULL;
    for (cgltf_size i = 0; i < prim->attributes_count; i++) {
        const cgltf_attribute *a = &prim->attributes[i];
        if (a->type == cgltf_attribute_type_position) pos = a->data;
        else if (a->type == cgltf_attribute_type_normal) nor = a->data;
        else if (a->type == cgltf_attribute_type_tangent) tan = a->data;
        else if (a->index == 0 && a->type == cgltf_attribute_type_texcoord) uv = a->data;
        else if (a->index == 0 && a->type == cgltf_attribute_type_color) col = a->data;
        else if (a->index == 0 && a->type == cgltf_attribute_type_joints) joi = a->data;
        else if (a->index == 0 && a->type == cgltf_attribute_type_weights) wei = a->data;
    }
    if (!pos || pos->count == 0) return fail(error, es, "%s: a mesh has no positions", rel);
    if (pos->count > FK_MAX_MODEL_VERTICES) return fail(error, es, "%s: a mesh has more than %d vertices", rel, FK_MAX_MODEL_VERTICES);
    const cgltf_accessor *all[] = {nor, uv, tan, col, joi, wei};
    for (int k = 0; k < 6; k++)
        if (all[k] && all[k]->count != pos->count) return fail(error, es, "%s: mesh attributes have different lengths", rel);
    int n = (int)pos->count;
    fk_vertex *v = p->vertices = calloc((size_t)n, sizeof *v);
    cgltf_size ni = prim->indices ? prim->indices->count : (cgltf_size)n;
    if (ni == 0 || ni % 3 || ni > 3 * FK_MAX_MODEL_VERTICES) return fail(error, es, "%s: mesh indices must describe whole triangles", rel);
    uint32_t *idx = p->indices = malloc(ni * sizeof *idx);
    if (!v || !idx) return fail(error, es, "%s: out of memory", rel);
    p->vertex_count = n;
    p->index_count = (int)ni;
    bool ok = true;
    for (int i = 0; i < n; i++) {
        float c[4] = {1, 1, 1, 1};
        ok = ok && read_floats(pos, (cgltf_size)i, v[i].position, 3);
        if (nor) ok = ok && read_floats(nor, (cgltf_size)i, v[i].normal, 3);
        if (uv) ok = ok && read_floats(uv, (cgltf_size)i, v[i].uv, 2);
        if (tan) ok = ok && read_floats(tan, (cgltf_size)i, v[i].tangent, 4);
        else v[i].tangent[0] = v[i].tangent[3] = 1;
        if (col) ok = ok && read_floats(col, (cgltf_size)i, c, cgltf_num_components(col->type));
        for (int k = 0; k < 3; k++) v[i].color[k] = powf(c[k] > 0 ? c[k] : 0, 1.0f / 2.2f); /* stored as sRGB */
        if (joi) {
            cgltf_uint j[4] = {0, 0, 0, 0};
            ok = ok && cgltf_accessor_read_uint(joi, (cgltf_size)i, j, 4);
            for (int k = 0; k < 4; k++) v[i].joints[k] = j[k] < FK_MAX_JOINTS ? (float)j[k] : 0;
        }
        if (wei) ok = ok && read_floats(wei, (cgltf_size)i, v[i].weights, 4);
        else v[i].weights[0] = 1;
    }
    if (!ok) return fail(error, es, "%s: a mesh uses an accessor that cannot be read (sparse accessors are not supported)", rel);
    for (cgltf_size i = 0; i < ni; i++) /* cgltf_validate has checked that indices stay below the vertex count */
        idx[i] = (uint32_t)(prim->indices ? cgltf_accessor_read_index(prim->indices, i) : i);
    if (!nor) fk_mesh_normals(v, n, idx, (int)ni);
    if (!tan && needs_tangents) fk_mesh_tangents(v, n, idx, (int)ni);
    p->material = prim->material ? (int)(prim->material - data->materials) : -1;
    return true;
}

static bool convert_clip(fk_clip *clip, const cgltf_animation *anim, int index, const cgltf_data *data, const char *rel, char *error,
                         size_t es) {
    if (anim->name) copy_name(clip->name, anim->name);
    else snprintf(clip->name, FK_NAME_SIZE, "clip%d", index + 1);
    clip->channels = calloc(anim->channels_count ? anim->channels_count : 1, sizeof *clip->channels);
    if (!clip->channels) return fail(error, es, "%s: out of memory", rel);
    for (cgltf_size i = 0; i < anim->channels_count; i++) {
        const cgltf_animation_channel *ch = &anim->channels[i];
        int path = ch->target_path == cgltf_animation_path_type_translation ? FK_PATH_TRANSLATION
                   : ch->target_path == cgltf_animation_path_type_rotation  ? FK_PATH_ROTATION
                   : ch->target_path == cgltf_animation_path_type_scale     ? FK_PATH_SCALE
                                                                             : -1;
        if (path < 0 || !ch->target_node) continue; /* morph target weights are not supported */
        const cgltf_animation_sampler *s = ch->sampler;
        int comps = path == FK_PATH_ROTATION ? 4 : 3;
        int interp = s->interpolation == cgltf_interpolation_type_step           ? FK_INTERP_STEP
                     : s->interpolation == cgltf_interpolation_type_cubic_spline ? FK_INTERP_CUBIC
                                                                                 : FK_INTERP_LINEAR;
        cgltf_size keys = s->input->count, per_key = interp == FK_INTERP_CUBIC ? 3 : 1;
        if (keys == 0 || s->output->count != keys * per_key) return fail(error, es, "%s: clip '%s' has mismatched keys", rel, clip->name);
        fk_channel *c = &clip->channels[clip->channel_count++];
        c->node = (int)(ch->target_node - data->nodes);
        c->path = path;
        c->interpolation = interp;
        c->count = (int)keys;
        c->times = malloc(keys * sizeof(float));
        c->values = malloc(keys * per_key * (cgltf_size)comps * sizeof(float));
        if (!c->times || !c->values) return fail(error, es, "%s: out of memory", rel);
        bool ok = true;
        for (cgltf_size k = 0; k < keys; k++) {
            ok = ok && read_floats(s->input, k, &c->times[k], 1);
            if (k && c->times[k] < c->times[k - 1]) ok = false;
        }
        for (cgltf_size k = 0; k < keys * per_key; k++) ok = ok && read_floats(s->output, k, &c->values[k * (cgltf_size)comps], (cgltf_size)comps);
        if (!ok) return fail(error, es, "%s: clip '%s' cannot be read", rel, clip->name);
        if (c->times[keys - 1] > clip->duration) clip->duration = c->times[keys - 1];
    }
    return true;
}

static const char *result_text(cgltf_result r) {
    switch (r) {
    case cgltf_result_file_not_found: return "a file it refers to is missing";
    case cgltf_result_io_error: return "it refers to a file outside data/";
    case cgltf_result_out_of_memory: return "out of memory";
    default: return "not a valid glTF file";
    }
}

static bool load(fk_model *m, const char *rel, cgltf_data **out, char *error, size_t es) {
    cgltf_options options;
    memset(&options, 0, sizeof options);
    options.file.read = read_file;
    options.file.release = release_file;
    size_t size;
    void *file = fk_vfs_read(rel, &size);
    if (!file) return fail(error, es, "cannot find %s", rel);
    cgltf_data *data = NULL;
    cgltf_result r = cgltf_parse(&options, file, size, &data);
    if (r == cgltf_result_success) {
        *out = data;
        r = cgltf_load_buffers(&options, data, rel);
        if (r == cgltf_result_success) r = cgltf_validate(data);
    }
    if (r != cgltf_result_success) {
        fk_platform_free(file);
        return fail(error, es, "%s: %s", rel, result_text(r));
    }
    data->file_data = file; /* freed with the data (cgltf releases it through options.file.release) */
    if (data->nodes_count > FK_MAX_MODEL_NODES) return fail(error, es, "%s: more than %d nodes", rel, FK_MAX_MODEL_NODES);

    /* Materials, and which images they use as colour (sRGB) or as data. */
    m->texture_count = (int)data->images_count;
    m->images = calloc(data->images_count + 1, sizeof *m->images);
    m->material_count = (int)data->materials_count;
    m->materials = calloc(data->materials_count + 1, sizeof *m->materials);
    if (!m->images || !m->materials) return fail(error, es, "%s: out of memory", rel);
    bool *used = calloc(data->images_count + 1, sizeof *used);
    if (!used) return fail(error, es, "%s: out of memory", rel);
    for (cgltf_size i = 0; i < data->materials_count; i++) {
        const cgltf_material *src = &data->materials[i];
        fk_model_material *mat = &m->materials[i];
        const cgltf_pbr_metallic_roughness *pbr = &src->pbr_metallic_roughness;
        memcpy(mat->base, pbr->base_color_factor, sizeof mat->base);
        mat->roughness = pbr->roughness_factor;
        mat->metalness = pbr->metallic_factor;
        memcpy(mat->emission, src->emissive_factor, sizeof mat->emission);
        if (src->has_emissive_strength)
            for (int k = 0; k < 3; k++) mat->emission[k] *= src->emissive_strength.emissive_strength;
        mat->normal_scale = src->normal_texture.texture ? src->normal_texture.scale : 1;
        mat->base_tex = texture_image(data, &pbr->base_color_texture);
        mat->metal_rough_tex = texture_image(data, &pbr->metallic_roughness_texture);
        mat->normal_tex = texture_image(data, &src->normal_texture);
        mat->emission_tex = texture_image(data, &src->emissive_texture);
        if (mat->base_tex >= 0) used[mat->base_tex] = m->images[mat->base_tex].srgb = true;
        if (mat->emission_tex >= 0) used[mat->emission_tex] = m->images[mat->emission_tex].srgb = true;
        if (mat->metal_rough_tex >= 0) used[mat->metal_rough_tex] = true; /* shortcut: an image used both as colour and data stays sRGB */
        if (mat->normal_tex >= 0) used[mat->normal_tex] = true;
    }
    bool ok = true;
    for (cgltf_size i = 0; ok && i < data->images_count; i++)
        if (used[i]) ok = load_image(&m->images[i], &data->images[i], &options, rel, error, es);
    free(used);
    if (!ok) return false;

    /* Meshes: every glTF mesh becomes a run of primitives that nodes refer to. */
    int *mesh_first = calloc(data->meshes_count + 1, sizeof *mesh_first);
    cgltf_size prims = 0;
    for (cgltf_size i = 0; i < data->meshes_count; i++) prims += data->meshes[i].primitives_count;
    m->primitives = calloc(prims + 1, sizeof *m->primitives);
    if (!mesh_first || !m->primitives) {
        free(mesh_first);
        return fail(error, es, "%s: out of memory", rel);
    }
    for (cgltf_size i = 0; ok && i < data->meshes_count; i++) {
        mesh_first[i] = m->primitive_count;
        for (cgltf_size k = 0; ok && k < data->meshes[i].primitives_count; k++) {
            const cgltf_primitive *prim = &data->meshes[i].primitives[k];
            bool tangents = prim->material && prim->material->normal_texture.texture;
            ok = convert_primitive(&m->primitives[m->primitive_count++], prim, data, tangents, rel, error, es);
        }
    }

    /* Nodes in glTF order, their rest pose, mesh and skin. */
    m->node_count = (int)data->nodes_count;
    m->nodes = calloc(data->nodes_count + 1, sizeof *m->nodes);
    if (ok && !m->nodes) ok = fail(error, es, "%s: out of memory", rel);
    for (cgltf_size i = 0; ok && i < data->nodes_count; i++) {
        const cgltf_node *src = &data->nodes[i];
        fk_node *node = &m->nodes[i];
        copy_name(node->name, src->name);
        node->parent = src->parent ? (int)(src->parent - data->nodes) : -1;
        node->skin = src->skin ? (int)(src->skin - data->skins) : -1;
        if (src->mesh) {
            cgltf_size mi = (cgltf_size)(src->mesh - data->meshes);
            node->first_primitive = mesh_first[mi];
            node->primitive_count = (int)src->mesh->primitives_count;
        }
        float local[16];
        cgltf_node_transform_local(src, local);
        for (int k = 0; k < 3; k++) {
            node->translation[k] = local[12 + k];
            node->scale[k] = sqrtf(local[k * 4] * local[k * 4] + local[k * 4 + 1] * local[k * 4 + 1] + local[k * 4 + 2] * local[k * 4 + 2]);
        }
        if (src->has_matrix) matrix_to_quat(local, node->scale, node->rotation);
        else memcpy(node->rotation, src->has_rotation ? src->rotation : (const float[4]){0, 0, 0, 1}, sizeof node->rotation);
        cgltf_node_transform_world(src, node->global);
    }
    free(mesh_first);

    /* Skins. */
    m->skin_count = (int)data->skins_count;
    m->skins = calloc(data->skins_count + 1, sizeof *m->skins);
    if (ok && !m->skins) ok = fail(error, es, "%s: out of memory", rel);
    for (cgltf_size i = 0; ok && i < data->skins_count; i++) {
        const cgltf_skin *src = &data->skins[i];
        fk_skin *skin = &m->skins[i];
        if (src->joints_count == 0 || src->joints_count > FK_MAX_JOINTS) {
            ok = fail(error, es, "%s: a skin must have 1 to %d joints", rel, FK_MAX_JOINTS);
            break;
        }
        skin->joint_count = (int)src->joints_count;
        skin->joints = malloc(src->joints_count * sizeof *skin->joints);
        skin->inverse_bind = malloc(src->joints_count * 16 * sizeof(float));
        if (!skin->joints || !skin->inverse_bind) {
            ok = fail(error, es, "%s: out of memory", rel);
            break;
        }
        for (cgltf_size j = 0; j < src->joints_count; j++) {
            skin->joints[j] = (int)(src->joints[j] - data->nodes);
            if (!src->inverse_bind_matrices) fk_mat4_identity(&skin->inverse_bind[j * 16]);
            else if (!read_floats(src->inverse_bind_matrices, j, &skin->inverse_bind[j * 16], 16)) ok = fail(error, es, "%s: a skin cannot be read", rel);
        }
    }

    /* Clips. */
    m->clips = calloc(data->animations_count + 1, sizeof *m->clips);
    if (ok && !m->clips) ok = fail(error, es, "%s: out of memory", rel);
    for (cgltf_size i = 0; ok && i < data->animations_count; i++) {
        ok = convert_clip(&m->clips[i], &data->animations[i], (int)i, data, rel, error, es);
        m->clip_count++;
    }
    return ok;
}

bool fk_model_load(fk_model *m, const char *rel, char *error, size_t error_size) {
    memset(m, 0, sizeof *m);
    cgltf_data *data = NULL;
    bool ok = load(m, rel, &data, error, error_size);
    cgltf_free(data);
    if (!ok) fk_model_free(m);
    return ok;
}

void fk_model_upload(fk_model *m) {
    if (!m->meshes) m->meshes = calloc((size_t)m->primitive_count + 1, sizeof *m->meshes);
    if (!m->textures) m->textures = calloc((size_t)m->texture_count + 1, sizeof *m->textures);
    if (!m->meshes || !m->textures) abort(); /* out of memory while loading: nothing sensible to continue with */
    for (int i = 0; i < m->primitive_count; i++) {
        fk_primitive *p = &m->primitives[i];
        if (!p->vertices) continue;
        fk_gfx_mesh_create(&m->meshes[i], p->vertices, p->vertex_count, p->indices, p->index_count);
        free(p->vertices);
        free(p->indices);
        p->vertices = NULL;
        p->indices = NULL;
    }
    for (int i = 0; i < m->texture_count; i++) {
        fk_model_image *img = &m->images[i];
        if (!img->rgba) continue;
        fk_gfx_texture_upload(&m->textures[i], img->rgba, img->width, img->height, img->srgb);
        fk_image_free(img->rgba);
        img->rgba = NULL;
    }
}

void fk_model_free(fk_model *m) {
    for (int i = 0; i < m->primitive_count; i++) {
        free(m->primitives[i].vertices);
        free(m->primitives[i].indices);
        if (m->meshes && m->meshes[i].vao) fk_gfx_mesh_destroy(&m->meshes[i]);
    }
    for (int i = 0; i < m->texture_count; i++) {
        if (m->images) fk_image_free(m->images[i].rgba);
        if (m->textures && m->textures[i].id) fk_gfx_texture_destroy(&m->textures[i]);
    }
    for (int i = 0; i < m->skin_count && m->skins; i++) {
        free(m->skins[i].joints);
        free(m->skins[i].inverse_bind);
    }
    for (int i = 0; i < m->clip_count; i++) {
        for (int c = 0; c < m->clips[i].channel_count; c++) {
            free(m->clips[i].channels[c].times);
            free(m->clips[i].channels[c].values);
        }
        free(m->clips[i].channels);
    }
    free(m->nodes);
    free(m->primitives);
    free(m->materials);
    free(m->images);
    free(m->skins);
    free(m->clips);
    free(m->meshes);
    free(m->textures);
    memset(m, 0, sizeof *m);
}

int fk_model_clip(const fk_model *m, const char *name) {
    for (int i = 0; i < m->clip_count; i++)
        if (strcmp(m->clips[i].name, name) == 0) return i;
    return -1;
}

int fk_model_node(const fk_model *m, const char *name) {
    for (int i = 0; i < m->node_count; i++)
        if (strcmp(m->nodes[i].name, name) == 0) return i;
    return -1;
}
