/* glTF 2.0 models (.glb and .gltf): meshes, PBR materials, textures, node hierarchy, skins and clips.
   Loading is plain C; fk_model_upload creates the GPU meshes and textures. */
#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "gfx/gfx.h"

#define FK_MAX_JOINTS 128
#define FK_NAME_SIZE 64

typedef struct {
    float base[4];                /* linear colour factor */
    float roughness, metalness;   /* factors */
    float emission[3];            /* linear factor */
    float normal_scale;
    int base_tex, metal_rough_tex, normal_tex, emission_tex; /* index into textures, -1: none */
} fk_model_material;

typedef struct {
    int material;            /* -1: the default material */
    fk_vertex *vertices;     /* CPU copy until fk_model_upload */
    uint32_t *indices;
    int vertex_count, index_count;
} fk_primitive;

typedef struct {
    char name[FK_NAME_SIZE];
    int parent;                                  /* -1: a root */
    float translation[3], rotation[4], scale[3]; /* rest pose; rotation x, y, z, w */
    float global[16];                            /* rest pose in model space */
    int first_primitive, primitive_count;        /* the node's mesh */
    int skin;                                    /* -1: not skinned */
} fk_node;

typedef struct {
    int joint_count;
    int *joints;         /* node indices */
    float *inverse_bind; /* 16 floats per joint */
} fk_skin;

enum { FK_PATH_TRANSLATION, FK_PATH_ROTATION, FK_PATH_SCALE };
enum { FK_INTERP_LINEAR, FK_INTERP_STEP, FK_INTERP_CUBIC };

typedef struct {
    int node, path, interpolation, count; /* count: keys */
    float *times;
    float *values; /* 3 or 4 floats per key; cubic splines hold in-tangent, value, out-tangent per key */
} fk_channel;

typedef struct {
    char name[FK_NAME_SIZE];
    float duration;
    int channel_count;
    fk_channel *channels;
} fk_clip;

typedef struct {
    uint8_t *rgba; /* CPU copy until fk_model_upload */
    int width, height;
    bool srgb;
} fk_model_image;

typedef struct {
    int node_count, primitive_count, material_count, texture_count, skin_count, clip_count;
    fk_node *nodes;
    fk_primitive *primitives;
    fk_model_material *materials;
    fk_model_image *images;
    fk_skin *skins;
    fk_clip *clips;
    fk_mesh *meshes;       /* one per primitive, after fk_model_upload */
    fk_texture *textures;  /* one per image, after fk_model_upload */
} fk_model;

/* Loads data/<rel> through the VFS. On failure returns false with a reason in error (and m is empty). */
bool fk_model_load(fk_model *m, const char *rel, char *error, size_t error_size);
/* Creates the GPU meshes and textures and drops the CPU copies of vertices and pixels. */
void fk_model_upload(fk_model *m);
void fk_model_free(fk_model *m);
/* The index of the clip or node with this name, or -1. */
int fk_model_clip(const fk_model *m, const char *name);
int fk_model_node(const fk_model *m, const char *name);
