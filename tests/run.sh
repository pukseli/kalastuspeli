#!/usr/bin/env bash
set -uo pipefail

GODOT="${GODOT:-$HOME/.local/bin/godot}"
if [[ ! -x "$GODOT" ]]; then
	echo "[FAIL] Godot not found: $GODOT"
	exit 2
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IMPORT_OUTPUT="$(timeout 120 "$GODOT" --headless --audio-driver Dummy --path "$PROJECT_DIR" --import 2>&1)"
IMPORT_EXIT=$?
if [[ $IMPORT_EXIT -eq 124 ]]; then
	echo "[FAIL] Timeout"
	exit 1
fi
if [[ $IMPORT_EXIT -ne 0 ]]; then
	printf '%s\n' "$IMPORT_OUTPUT"
	echo "[FAIL] Import failed"
	exit 1
fi

OUTPUT="$(timeout 120 "$GODOT" --headless --audio-driver Dummy --path "$PROJECT_DIR" --script res://tests/run_tests.gd 2>&1)"
TEST_EXIT=$?
printf '%s\n' "$OUTPUT"

if [[ $TEST_EXIT -eq 124 ]]; then
	echo "[FAIL] Timeout"
	exit 1
fi

if printf '%s\n' "$OUTPUT" | grep -Eq '^(SCRIPT ERROR|ERROR):'; then
	echo "[FAIL] Engine reported errors"
	exit 1
fi

if [[ $TEST_EXIT -ne 0 ]]; then
	exit "$TEST_EXIT"
fi

echo "[PASS] Gatekeeper OK"
exit 0
