#include <stdint.h>

#include "core/jobs.h"
#include "utest.h"

static void square(void *data) {
    int64_t *v = data;
    int64_t x = *v, sum = 0;
    for (int64_t i = 0; i < 2000; i++) sum += x * x + i;
    *v = sum;
}

static int64_t expected(int64_t x) { return 2000 * x * x + 1999 * 2000 / 2; }

UTEST(jobs, workers_run_everything) {
    int workers = fk_jobs_start(3);
    EXPECT_GE(workers, 0);
    static int64_t values[300];
    uint32_t ids[300];
    for (int i = 0; i < 300; i++) values[i] = i, ids[i] = fk_jobs_submit(square, &values[i]);
    for (int i = 0; i < 300; i++) fk_jobs_wait(ids[i]);
    for (int i = 0; i < 300; i++) {
        ASSERT_TRUE(fk_jobs_done(ids[i]));
        ASSERT_EQ(values[i], expected(i));
    }
    EXPECT_TRUE(fk_jobs_done(ids[0]));
    EXPECT_FALSE(fk_jobs_done(ids[299] + 1000)); /* never submitted */
    fk_jobs_wait(ids[299] + 1000);               /* returns at once */
    fk_jobs_stop();
}

UTEST(jobs, time_sliced_without_workers) {
    EXPECT_EQ(fk_jobs_start(0), 0);
    static int64_t values[100];
    uint32_t ids[100];
    for (int i = 0; i < 100; i++) values[i] = i, ids[i] = fk_jobs_submit(square, &values[i]);
    EXPECT_GT(ids[1], ids[0]);
    EXPECT_FALSE(fk_jobs_done(ids[0]));
    fk_jobs_update(0); /* runs at least one */
    EXPECT_TRUE(fk_jobs_done(ids[0]));
    fk_jobs_wait(ids[50]); /* runs the queue up to it */
    EXPECT_TRUE(fk_jobs_done(ids[50]));
    fk_jobs_run(3); /* exactly three more, in order */
    EXPECT_TRUE(fk_jobs_done(ids[53]));
    EXPECT_FALSE(fk_jobs_done(ids[54]));
    fk_jobs_update(UINT64_MAX);
    for (int i = 0; i < 100; i++) ASSERT_EQ(values[i], expected(i));
    fk_jobs_stop();
}
