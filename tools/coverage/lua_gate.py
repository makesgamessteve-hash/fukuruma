"""Fails when Lua line coverage of data/scripts (from a luacov report) is below a threshold.

usage: lua_gate.py luacov.report.out 95
"""
import re
import sys

report, threshold = sys.argv[1], float(sys.argv[2])
hits = missed = 0
summary = open(report, encoding="utf-8").read().split("Summary", 1)[-1]
for line in summary.splitlines():
    m = re.match(r"^(\S*data/scripts/\S+)\s+(\d+)\s+(\d+)\s+[\d.]+%$", line.strip())
    if m:
        print(line.strip())
        hits += int(m.group(2))
        missed += int(m.group(3))
total = hits + missed
coverage = 100.0 * hits / total if total else 0.0
print(f"Lua coverage of data/scripts: {coverage:.2f}% ({hits} of {total} lines)")
sys.exit(0 if total and coverage >= threshold else 1)
