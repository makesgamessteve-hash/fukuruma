/* Golden-image comparison for game-test screenshots. */
#pragma once
#include <stdbool.h>
#include <stdint.h>

/* Counts pixels where any channel differs by more than tolerance. Marks them red in diff (w*h RGBA) if not NULL. */
int fk_image_diff(const uint8_t *a, const uint8_t *b, int w, int h, int tolerance, uint8_t *diff);

/* Writes the frame to <out_dir>/<name>.png, then compares it with the reference image golden
   (or replaces the reference when update is set). Fails when more than 0.5% of pixels differ by more
   than 8/255; the diff image is then written to <out_dir>/<name>-diff.png. Logs the outcome. */
bool fk_golden_check(const char *golden, const char *out_dir, const char *name, const uint8_t *rgba, int w, int h,
                     bool update);
