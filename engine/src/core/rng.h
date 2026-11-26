/* Deterministic hashing and random streams: integer-only, identical on every platform. */
#pragma once
#include <stddef.h>
#include <stdint.h>

#define FK_HASH_INIT 0xcbf29ce484222325ull

/* FNV-1a 64 over n bytes, continuing from h (start with FK_HASH_INIT). */
uint64_t fk_hash_bytes(uint64_t h, const void *data, size_t n);
/* Continues h with v as 8 little-endian bytes. */
uint64_t fk_hash_u64(uint64_t h, uint64_t v);
/* SplitMix64 finaliser: spreads a hash into a well-mixed seed. */
uint64_t fk_mix64(uint64_t x);

typedef struct {
    uint64_t s[4];
} fk_rng;

void fk_rng_seed(fk_rng *r, uint64_t seed);
uint64_t fk_rng_next(fk_rng *r);  /* xoshiro256** */
double fk_rng_float(fk_rng *r);   /* [0, 1) */
uint64_t fk_rng_below(fk_rng *r, uint64_t n); /* [0, n), unbiased; n > 0 */
