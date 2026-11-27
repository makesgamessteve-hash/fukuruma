/* The job system (plan 3.2): background work such as generation. Worker threads on desktop; on the web (no
   threads) jobs run time-sliced on the main thread in fk_jobs_update. A job's result must not depend on when or
   where it runs, so generation stays deterministic. */
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef void (*fk_job_fn)(void *data);

/* Starts the workers: workers < 0 picks one fewer than the CPU cores (at most 8); 0 runs every job time-sliced on
   the main thread. Returns the number of worker threads running. */
int fk_jobs_start(int workers);
void fk_jobs_stop(void); /* finishes queued jobs, then stops the workers */
/* Queues fn(data) and returns its job number (never 0). */
uint32_t fk_jobs_submit(fk_job_fn fn, void *data);
bool fk_jobs_done(uint32_t job);
/* Waits for a job, running queued jobs on this thread meanwhile (so it also works without workers). */
void fk_jobs_wait(uint32_t job);
/* Runs queued jobs on this thread for up to budget_ns (the web's time slice; harmless with workers). */
void fk_jobs_update(uint64_t budget_ns);
/* Runs up to count queued jobs on this thread: a fixed amount of background work per frame, the same on every
   machine (test scenarios, whose pictures must not depend on the machine's speed). */
void fk_jobs_run(int count);
