#!/usr/bin/env bash
# Run every headless test suite and summarise.
#
# Usage:  bash test/run_all.sh  [path-to-godot]
#
# Exits non-zero if any suite fails. Also fails a suite that printed PASS while
# emitting a SCRIPT ERROR — a compile error inside a test function aborts
# execution mid-way and can leave zero assertions run, which otherwise reports
# as a pass. That false-pass has bitten twice; treat it as a failure.

set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${1:-/c/Users/White/Documents/Godot/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe}"
if [ ! -x "$GODOT" ]; then
  echo "Godot binary not found or not executable: $GODOT"
  echo "Pass the path as the first argument."
  exit 2
fi

fails=0
suites=0

for f in test/*_test.gd; do
  name="$(basename "$f" .gd)"
  suites=$((suites + 1))
  out="$("$GODOT" --headless --script "$f" 2>&1)"
  code=$?
  verdict="$(printf '%s\n' "$out" | grep -E 'TESTS?: (PASS|FAIL)' | tail -1)"

  # A SCRIPT ERROR during the run means some assertions never executed, even if
  # the suite printed PASS. Godot logs a benign first-pass compile error for
  # scripts that reference autoloads, so only count errors naming a test file.
  script_err="$(printf '%s\n' "$out" | grep -E 'SCRIPT ERROR|Nonexistent function' | grep -c "$name" || true)"

  if [ "$code" -ne 0 ]; then
    echo "FAIL  $name  ${verdict:-(no verdict printed)}"
    printf '%s\n' "$out" | grep -E '^  - ' || true
    fails=$((fails + 1))
  elif [ "$script_err" -gt 0 ]; then
    echo "FAIL  $name  (printed PASS but hit a SCRIPT ERROR — assertions may not have run)"
    printf '%s\n' "$out" | grep -E 'SCRIPT ERROR|Nonexistent function' | head -3
    fails=$((fails + 1))
  else
    echo "ok    $name  ${verdict}"
  fi
done

echo
if [ "$fails" -eq 0 ]; then
  echo "All $suites suite(s) passed."
  exit 0
fi
echo "$fails of $suites suite(s) FAILED."
exit 1
