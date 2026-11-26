/* Command-line options. */
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    bool headless, no_render, update_golden, coverage, seed_given;
    const char *test_dir, *scenario;
    uint64_t seed;
} fk_options;

/* Parses argv into o (defaults: seed 1). Logs the problem and the usage and returns false on bad input. */
bool fk_cli_parse(int argc, char **argv, fk_options *o);
