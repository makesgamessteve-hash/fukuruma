#include "app/cli.h"

#include <errno.h>
#include <stdlib.h>
#include <string.h>

#include "platform/platform.h"

static bool fail(const char *what, const char *arg) {
    fk_log("%s: %s\nusage: fukuruma [--headless | --no-render] [--seed N] [--scenario FILE [--update-golden]] "
           "[--test DIR [--coverage]]",
           what, arg);
    return false;
}

bool fk_cli_parse(int argc, char **argv, fk_options *o) {
    memset(o, 0, sizeof *o);
    o->seed = 1;
    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
        bool has_value = i + 1 < argc;
        if (strcmp(a, "--headless") == 0) o->headless = true;
        else if (strcmp(a, "--no-render") == 0) o->no_render = true;
        else if (strcmp(a, "--update-golden") == 0) o->update_golden = true;
        else if (strcmp(a, "--coverage") == 0) o->coverage = true;
        else if (strcmp(a, "--test") == 0 && has_value) o->test_dir = argv[++i];
        else if (strcmp(a, "--scenario") == 0 && has_value) o->scenario = argv[++i];
        else if (strcmp(a, "--seed") == 0 && has_value) {
            const char *v = argv[++i];
            char *end;
            errno = 0;
            o->seed = strtoull(v, &end, 10);
            if (*v < '0' || *v > '9' || *end || errno) return fail("--seed needs an unsigned 64-bit integer", v);
            o->seed_given = true;
        } else if (strncmp(a, "-psn_", 5) == 0) continue; /* added by macOS when started from Finder */
        else return fail("unknown or incomplete option", a);
    }
    return true;
}
