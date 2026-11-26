#include "assets/image.h"

#include <limits.h>

#include "stb_image.h"

#define FK_MAX_IMAGE_SIDE 8192

uint8_t *fk_image_decode(const void *data, size_t size, int *width, int *height, const char **error) {
    int n, w, h;
    if (size > INT_MAX || !stbi_info_from_memory(data, (int)size, &w, &h, &n)) {
        *error = "not a PNG or JPEG image";
        return NULL;
    }
    if (w > FK_MAX_IMAGE_SIDE || h > FK_MAX_IMAGE_SIDE) {
        *error = "larger than 8192 pixels on a side";
        return NULL;
    }
    uint8_t *pixels = stbi_load_from_memory(data, (int)size, width, height, &n, 4);
    if (!pixels) *error = stbi_failure_reason();
    return pixels;
}

void fk_image_free(uint8_t *pixels) { stbi_image_free(pixels); }
