#!/usr/bin/env bash
set -uo pipefail

GODOT="${GODOT:-$HOME/.local/bin/godot}"
if [[ ! -x "$GODOT" ]]; then
	echo "[FAIL] Godot not found: $GODOT"
	exit 2
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! "$GODOT" --headless --audio-driver Dummy --path "$PROJECT_DIR" --import >/dev/null 2>&1; then
	echo "[FAIL] Import failed"
	exit 1
fi

OUTPUT="$("$GODOT" --headless --audio-driver Dummy --path "$PROJECT_DIR" --script res://tests/run_tests.gd 2>&1)"
TEST_EXIT=$?
printf '%s\n' "$OUTPUT"

if printf '%s\n' "$OUTPUT" | grep -Eq '^(SCRIPT ERROR|ERROR):'; then
	echo "[FAIL] Engine reported errors"
	exit 1
fi

if [[ $TEST_EXIT -ne 0 ]]; then
	exit "$TEST_EXIT"
fi

echo "[PASS] Gatekeeper OK"
exit 0
