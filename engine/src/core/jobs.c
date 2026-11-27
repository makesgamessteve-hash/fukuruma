#include "core/jobs.h"

#include <stdlib.h>

#include "platform/platform.h"

#define MAX_WORKERS 8

typedef struct {
    fk_job_fn fn;
    void *data;
    uint32_t id;
} job;

static struct {
    job *queue; /* a ring */
    int head, count, cap;
    uint32_t next_id, finished_below; /* every job below finished_below is done */
    uint8_t *done;                    /* done flags from finished_below on, as a ring of done_cap */
    int done_cap;
    void *lock, *wake;
    void *threads[MAX_WORKERS];
    int nthreads;
    bool stopping;
} J = {.next_id = 1, .finished_below = 1};

static void grow_done(void) { /* room for flags of every job from finished_below to next_id */
    int need = (int)(J.next_id - J.finished_below) + 1;
    if (need <= J.done_cap) return;
    int cap = J.done_cap ? J.done_cap * 2 : 64;
    while (cap < need) cap *= 2;
    uint8_t *d = calloc((size_t)cap, 1);
    if (!d) abort();
    for (uint32_t i = J.finished_below; J.done_cap && i < J.next_id; i++) d[i % (uint32_t)cap] = J.done[i % (uint32_t)J.done_cap];
    free(J.done);
    J.done = d, J.done_cap = cap;
}

static bool take(job *out) { /* with the lock held */
    if (!J.count) return false;
    *out = J.queue[J.head];
    J.head = (J.head + 1) % J.cap;
    J.count--;
    return true;
}

static void finish(uint32_t id) { /* with the lock held */
    J.done[id % (uint32_t)J.done_cap] = 1;
    while (J.finished_below < J.next_id && J.done[J.finished_below % (uint32_t)J.done_cap]) {
        J.done[J.finished_below % (uint32_t)J.done_cap] = 0;
        J.finished_below++;
    }
    fk_platform_cond_wake_all(J.wake);
}

static void run(const job *j) {
    j->fn(j->data);
    fk_platform_lock(J.lock);
    finish(j->id);
    fk_platform_unlock(J.lock);
}

static int worker(void *arg) {
    (void)arg;
    fk_platform_lock(J.lock);
    for (;;) {
        job j;
        if (take(&j)) {
            fk_platform_unlock(J.lock);
            run(&j);
            fk_platform_lock(J.lock);
        } else if (J.stopping) {
            break;
        } else {
            fk_platform_cond_wait(J.wake, J.lock);
        }
    }
    fk_platform_unlock(J.lock);
    return 0;
}

int fk_jobs_start(int workers) {
    if (!J.lock) J.lock = fk_platform_mutex(), J.wake = fk_platform_cond();
    if (workers < 0) workers = fk_platform_cpus() - 1;
    if (workers > MAX_WORKERS) workers = MAX_WORKERS;
    J.stopping = false;
    for (int i = J.nthreads; i < workers; i++) {
        void *t = fk_platform_thread_start(worker, NULL, "fk_job");
        if (!t) break;
        J.threads[J.nthreads++] = t;
    }
    return J.nthreads;
}

void fk_jobs_stop(void) {
    fk_jobs_update(UINT64_MAX);
    fk_platform_lock(J.lock);
    J.stopping = true;
    fk_platform_cond_wake_all(J.wake);
    fk_platform_unlock(J.lock);
    for (int i = 0; i < J.nthreads; i++) fk_platform_thread_join(J.threads[i]);
    J.nthreads = 0;
}

uint32_t fk_jobs_submit(fk_job_fn fn, void *data) {
    if (!J.lock) fk_jobs_start(0);
    fk_platform_lock(J.lock);
    if (J.count == J.cap) {
        int cap = J.cap ? J.cap * 2 : 64;
        job *q = malloc((size_t)cap * sizeof *q);
        if (!q) abort();
        for (int i = 0; i < J.count; i++) q[i] = J.queue[(J.head + i) % J.cap];
        free(J.queue);
        J.queue = q, J.cap = cap, J.head = 0;
    }
    uint32_t id = J.next_id++;
    grow_done();
    J.queue[(J.head + J.count) % J.cap] = (job){fn, data, id};
    J.count++;
    fk_platform_cond_wake_all(J.wake);
    fk_platform_unlock(J.lock);
    return id;
}

bool fk_jobs_done(uint32_t id) {
    fk_platform_lock(J.lock);
    bool done = id < J.finished_below || (id < J.next_id && J.done[id % (uint32_t)J.done_cap]);
    fk_platform_unlock(J.lock);
    return done;
}

void fk_jobs_wait(uint32_t id) {
    fk_platform_lock(J.lock);
    for (;;) {
        if (id >= J.next_id || id < J.finished_below || J.done[id % (uint32_t)J.done_cap]) break;
        job j;
        if (take(&j)) { /* help instead of idling */
            fk_platform_unlock(J.lock);
            run(&j);
            fk_platform_lock(J.lock);
        } else {
            fk_platform_cond_wait(J.wake, J.lock); /* a worker is running it */
        }
    }
    fk_platform_unlock(J.lock);
}

static bool run_one(void) {
    fk_platform_lock(J.lock);
    job j;
    bool got = take(&j);
    fk_platform_unlock(J.lock);
    if (got) run(&j);
    return got;
}

void fk_jobs_update(uint64_t budget_ns) {
    uint64_t start = fk_platform_ticks_ns();
    while (run_one() && fk_platform_ticks_ns() - start < budget_ns) {}
}

void fk_jobs_run(int count) {
    for (int i = 0; i < count && run_one(); i++) {}
}
