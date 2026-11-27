#!/usr/bin/env bash
# The local gates before a push (AGENTS.md): every test with the coverage gates (C and Lua >= 95%), the sanitizers,
# and the browser suite. The coverage run is the full test suite, so no separate debug run is needed.
# usage: tools/qa.sh [emsdk_env.sh]   (without an Emscripten environment the browser suite is skipped and reported)
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
step coverage cmake --build --preset linux-coverage --target coverage
step asan sh -c 'cmake --build --preset linux-asan && ctest --preset linux-asan --parallel "$(nproc)"'
if [ -n "${1:-}" ] && [ -f "$1" ]; then
  step web bash -c "source '$1' >/dev/null 2>&1 && cmake --build --preset web && cd tests/web && node smoke.mjs ../../build/web"
else
  echo "SKIP web (no emsdk_env.sh given)"; status=1
fi
grep -hE "^lines:|Lua coverage" "$log/coverage.txt" 2>/dev/null
exit $status
