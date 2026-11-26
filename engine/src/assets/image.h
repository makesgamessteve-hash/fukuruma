/* Decodes PNG and JPEG files to RGBA8 pixels. Plain C. */
#pragma once
#include <stddef.h>
#include <stdint.h>

/* Returns width x height RGBA8 pixels, top row first (free with fk_image_free), or NULL with a reason. */
uint8_t *fk_image_decode(const void *data, size_t size, int *width, int *height, const char **error);
void fk_image_free(uint8_t *pixels);
