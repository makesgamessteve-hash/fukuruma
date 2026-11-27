#!/usr/bin/env bash
# The local gates (AGENTS.md).
#   tools/qa.sh [scenario ...]              after every change: the build, the unit and Lua tests, the quick game
#                                           scenarios (ctest -LE slow), and the named scenarios of the change at hand
#                                           (e.g. chain), slow or not
#   tools/qa.sh milestone [emsdk_env.sh]    at the end of a milestone: every test with the coverage gates (C and Lua
#                                           >= 95%), the sanitizers and the browser suite
# CI runs everything on every push either way.
set -u
cd "$(dirname "$0")/.."
log=build/qa
mkdir -p "$log"
status=0
step() { # name, command...: runs it, logs it, records the result
  local name=$1; shift
  local start=$SECONDS
  if "$@" > "$log/$name.txt" 2>&1; then echo "PASS $name ($((SECONDS - start)) s)"
  else echo "FAIL $name ($((SECONDS - start)) s): see $log/$name.txt"; status=1; fi
}
if [ "${1:-}" != milestone ]; then
  step build cmake --build --preset linux-debug
  step quick ctest --preset linux-debug -LE slow --parallel "$(nproc)"
  for scenario in "$@"; do step "game_$scenario" ctest --preset linux-debug -R "^game_${scenario}\$"; done
  exit $status
fi
step coverage cmake --build --preset linux-coverage --target coverage
step asan sh -c 'cmake --build --preset linux-asan && ctest --preset linux-asan --parallel "$(nproc)"'
if [ -n "${2:-}" ] && [ -f "$2" ]; then
  step web bash -c "source '$2' >/dev/null 2>&1 && cmake --build --preset web && cd tests/web && node smoke.mjs ../../build/web"
else
  echo "SKIP web (no emsdk_env.sh given)"; status=1
fi
grep -hE "^lines:|Lua coverage" "$log/coverage.txt" 2>/dev/null
exit $status
