#include "app/golden.h"

#include <stdio.h>
#include <stdlib.h>

#include "platform/platform.h"
#include "stb_image.h"
#include "stb_image_write.h"

int fk_image_diff(const uint8_t *a, const uint8_t *b, int w, int h, int tolerance, uint8_t *diff) {
    int count = 0;
    for (int i = 0; i < w * h; i++) {
        int worst = 0;
        for (int c = 0; c < 4; c++) {
            int d = abs(a[i * 4 + c] - b[i * 4 + c]);
            if (d > worst) worst = d;
        }
        bool differs = worst > tolerance;
        count += differs;
        if (diff) { /* differing pixels red, the rest a faded copy of the reference */
            diff[i * 4 + 0] = differs ? 255 : b[i * 4 + 0] / 4;
            diff[i * 4 + 1] = differs ? 0 : b[i * 4 + 1] / 4;
            diff[i * 4 + 2] = differs ? 0 : b[i * 4 + 2] / 4;
            diff[i * 4 + 3] = 255;
        }
    }
    return count;
}

bool fk_golden_check(const char *golden, const char *out_dir, const char *name, const uint8_t *rgba, int w, int h,
                     bool update) {
    char path[1100];
    fk_platform_make_dir(out_dir);
    snprintf(path, sizeof path, "%s/%s.png", out_dir, name);
    stbi_write_png(path, w, h, 4, rgba, w * 4);
    if (update) {
        bool ok = stbi_write_png(golden, w, h, 4, rgba, w * 4) != 0;
        fk_log(ok ? "updated reference image %s" : "cannot write reference image %s", golden);
        return ok;
    }
    int gw, gh, n;
    uint8_t *ref = stbi_load(golden, &gw, &gh, &n, 4);
    if (!ref) {
        fk_log("missing reference image %s (create it with --update-golden)", golden);
        return false;
    }
    bool ok = gw == w && gh == h;
    if (!ok) fk_log("screenshot '%s' is %dx%d, the reference is %dx%d", name, w, h, gw, gh);
    else {
        uint8_t *diff = malloc((size_t)w * h * 4);
        int count = fk_image_diff(rgba, ref, w, h, 8, diff);
        ok = count * 1000 <= w * h * 5;
        if (!ok) {
            snprintf(path, sizeof path, "%s/%s-diff.png", out_dir, name);
            stbi_write_png(path, w, h, 4, diff, w * 4);
        }
        fk_log("screenshot '%s': %d of %d pixels differ%s", name, count, w * h, ok ? "" : " (more than 0.5%)");
        free(diff);
    }
    stbi_image_free(ref);
    return ok;
}
