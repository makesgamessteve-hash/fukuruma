#include "core/rng.h"

uint64_t fk_hash_bytes(uint64_t h, const void *data, size_t n) {
    const unsigned char *p = data;
    for (size_t i = 0; i < n; i++) h = (h ^ p[i]) * 0x100000001b3ull;
    return h;
}

uint64_t fk_hash_u64(uint64_t h, uint64_t v) {
    unsigned char b[8];
    for (int i = 0; i < 8; i++) b[i] = (unsigned char)(v >> (8 * i));
    return fk_hash_bytes(h, b, 8);
}

uint64_t fk_mix64(uint64_t x) {
    x = (x ^ (x >> 30)) * 0xbf58476d1ce4e5b9ull;
    x = (x ^ (x >> 27)) * 0x94d049bb133111ebull;
    return x ^ (x >> 31);
}

void fk_rng_seed(fk_rng *r, uint64_t seed) {
    for (int i = 0; i < 4; i++) r->s[i] = fk_mix64(seed += 0x9e3779b97f4a7c15ull);
}

static uint64_t rotl(uint64_t x, int k) { return (x << k) | (x >> (64 - k)); }

uint64_t fk_rng_next(fk_rng *r) {
    uint64_t *s = r->s, result = rotl(s[1] * 5, 7) * 9, t = s[1] << 17;
    s[2] ^= s[0];
    s[3] ^= s[1];
    s[1] ^= s[2];
    s[0] ^= s[3];
    s[2] ^= t;
    s[3] = rotl(s[3], 45);
    return result;
}

double fk_rng_float(fk_rng *r) { return (double)(fk_rng_next(r) >> 11) / 9007199254740992.0; /* 2^53 */ }

uint64_t fk_rng_below(fk_rng *r, uint64_t n) {
    uint64_t limit = UINT64_MAX - UINT64_MAX % n; /* values at or above limit would bias the result */
    uint64_t x;
    do x = fk_rng_next(r);
    while (x >= limit);
    return x % n;
}
