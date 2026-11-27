# Proposal

## Why

Generation is the first background work (plan §3.2, moved here from M1): galaxy sectors now, star systems, planets
and terrain chunks next. It must not stall frames, and on the web (no WebAssembly threads on GitHub Pages) it must
still run, a little each frame.

## What Changes

- `core/jobs.c`: a queue of C jobs run by worker threads (one fewer than the CPU cores, at most 8); `submit`, `done`,
  `wait` (which runs queued jobs itself), `update` (runs jobs on the calling thread for a time budget) and `stop`.
- `platform/`: threads, mutexes and condition variables behind SDL (only `platform/` calls SDL); none on the web.
- The app starts the workers, gives the web build 2 ms of jobs per frame, and stops them before closing the scripts.

## Capabilities

### New Capabilities
- `jobs`: background jobs on threads or time-sliced.

## Impact

`engine/src/core/jobs.{c,h}`, `engine/src/platform/platform.{c,h}`, `engine/src/app/app.c`, `tests/unit/test_jobs.c`.
