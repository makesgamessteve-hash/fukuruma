## Purpose

Runs background work (generation) on worker threads on desktop and time-sliced on the main thread on the web.

## ADDED Requirements

### Requirement: Background jobs
The engine SHALL run submitted C jobs on worker threads when the platform has them, and otherwise on the main thread
within a per-frame time budget. Waiting for a job SHALL run queued jobs on the waiting thread, so it finishes with or
without workers. A job's result SHALL not depend on where or when it runs.

#### Scenario: Many jobs on workers
- **WHEN** 300 jobs are submitted and waited for with worker threads running
- **THEN** every job has run exactly once with the right result

#### Scenario: No threads
- **WHEN** jobs are submitted without workers and the frame runs its time slice
- **THEN** queued jobs run on the main thread, and waiting for a later job runs the queue up to it
