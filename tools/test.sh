#!/bin/zsh
# Runs every headless test for VOWFALL. No window opens.
# Fails if any check fails, or if any script error was printed along the way
# (a script error inside a draw or a signal handler does not fail a check by
# itself, so the logs are searched for them).
cd "$(dirname "$0")/.."
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
OUT=$(mktemp -d)
rc=0

$G --headless --path game --import > "$OUT/import.txt" 2>&1

echo "== Law Engine"
$G --headless --path game --script res://tests/run_tests.gd "$@" > "$OUT/law.txt" 2>&1 || rc=1
grep -E "FAIL|passed," "$OUT/law.txt"

echo "== M1: action machine and arena"
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM1.tscn "$@" > "$OUT/m1.txt" 2>&1 || rc=1
grep -E "FAIL|passed,|us per tick" "$OUT/m1.txt"

echo "== M2: Axioms in play"
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM2.tscn "$@" > "$OUT/m2.txt" 2>&1 || rc=1
grep -E "FAIL|passed,|won|LOST|open " "$OUT/m2.txt"

echo "== M3: Instruments and Unveiling"
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM3.tscn "$@" > "$OUT/m3.txt" 2>&1 || rc=1
grep -E "FAIL|passed," "$OUT/m3.txt"

echo "== M4: Aurel Voss"
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM4.tscn "$@" > "$OUT/m4.txt" 2>&1 || rc=1
grep -E "FAIL|passed,|yields|FELL|open  " "$OUT/m4.txt"

echo "== M5: the Assize Quarter"
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM5.tscn "$@" > "$OUT/m5.txt" 2>&1 || rc=1
grep -E "FAIL|passed,|us per tick" "$OUT/m5.txt"

if grep -h -E "SCRIPT ERROR|Parse Error|Invalid (call|get|set|type|access)|Lambda capture" "$OUT"/*.txt; then
	echo "script errors were printed: see $OUT"
	rc=1
fi
[ $rc -eq 0 ] && echo "ALL TESTS PASSED" || echo "TESTS FAILED (logs in $OUT)"
exit $rc
