#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$PROJECT_DIR"

LOCK_FILE=".agents/slice_lock.sha256"

echo "=== [1/5] Checking Slice Spec Line Limits (<= 60) & Slice Test Counts (<= 5) ==="
VIOLATIONS=0
for spec in specs/slices/*.md; do
  [[ "$spec" =~ _template\.md$ ]] && continue
  [ -f "$spec" ] || continue

  NON_EMPTY_LINES=$(grep -c '[^[:space:]]' "$spec" || true)
  if [ "$NON_EMPTY_LINES" -gt 60 ]; then
    echo "[FAIL] $spec has $NON_EMPTY_LINES non-empty lines (max allowed: 60)"
    VIOLATIONS=$((VIOLATIONS + 1))
  else
    echo "[OK] $spec ($NON_EMPTY_LINES lines)"
  fi
done

for test_file in tests/test_[0-9][0-9]_*.gd; do
  [ -f "$test_file" ] || continue
  TEST_COUNT=$(grep -cE '^[[:space:]]*func[[:space:]]+test_' "$test_file" || true)
  if [ "$TEST_COUNT" -gt 5 ]; then
    echo "[FAIL] $test_file has $TEST_COUNT test methods (max allowed: 5)"
    VIOLATIONS=$((VIOLATIONS + 1))
  else
    echo "[OK] $test_file ($TEST_COUNT tests)"
  fi
done

if [ "$VIOLATIONS" -gt 0 ]; then
  echo "Slice size limit violation! Split the slice according to specs/00-architecture.md §5."
  exit 1
fi

echo ""
echo "=== [2/5] Checking Single Scene Rule (src/main.tscn only) ==="
SCENES=$(find src -name "*.tscn" | LC_ALL=C sort)
if [ "$SCENES" != "src/main.tscn" ]; then
  echo "[FAIL] Single Scene Rule violated! Expected only 'src/main.tscn', found:"
  echo "$SCENES"
  exit 1
fi
echo "[OK] Single scene verified (src/main.tscn)."

echo ""
echo "=== [3/5] Checking Headless Core Boundary (src/core/) ==="
CORE_FORBIDDEN='\b(Node|Node2D|Node3D|Control|CanvasItem|MeshInstance3D|Camera3D|Light3D|DirectionalLight3D|WorldEnvironment|Viewport|Window|SceneTree|MultiplayerAPI|MultiplayerPeer|ENetMultiplayerPeer|WebRTCMultiplayerPeer|SteamMultiplayerPeer|RigidBody3D|CharacterBody3D|Area3D|CollisionShape3D|AudioStreamPlayer|AudioStreamPlayer3D|InputEvent)\b|\bInput\.|res://src/(view|network)/'
CORE_VIOLATIONS=0
while IFS= read -r -d '' core_file; do
  MATCHES=$(sed 's/#.*//' "$core_file" | grep -nE "$CORE_FORBIDDEN" || true)
  if [ -n "$MATCHES" ]; then
    echo "[FAIL] Forbidden Node/View/Network dependency in $core_file:"
    echo "$MATCHES"
    CORE_VIOLATIONS=$((CORE_VIOLATIONS + 1))
  fi
done < <(find src/core -name "*.gd" -print0 | LC_ALL=C sort -z)

if [ "$CORE_VIOLATIONS" -gt 0 ]; then
  echo "Headless Core Boundary violated! Keep src/core/ pure RefCounted logic."
  exit 1
fi
echo "[OK] src/core/ has zero Node/View/Network dependencies."

echo ""
echo "=== [4/5] Checking Test & Spec Immutability ==="
if [ -f "$LOCK_FILE" ]; then
  bash .agents/skills/godot-gatekeeper/scripts/lock_slice.sh --verify
elif [ "${ALLOW_TEST_EDITS:-0}" = "1" ]; then
  echo "[WARN] Tracked test immutability check bypassed (ALLOW_TEST_EDITS=1)."
else
  DIFF_TESTS=$({
    git diff --diff-filter=MD --name-only -- tests/run.sh tests/run_tests.gd 'tests/test_*.gd' || true
    git diff --cached --diff-filter=MD --name-only -- tests/run.sh tests/run_tests.gd 'tests/test_*.gd' || true
  } | LC_ALL=C sort -u)
  if [ -n "$DIFF_TESTS" ]; then
    echo "[FAIL] Tracked test or harness files were modified/deleted:"
    echo "$DIFF_TESTS"
    echo "Revert accidental builder edits (git checkout -- tests/) or re-run with ALLOW_TEST_EDITS=1 if intentional."
    exit 1
  fi
  echo "[OK] No tracked test or harness files modified (tip: run lock_slice.sh before builder runs to lock new untracked tests too)."
fi

echo ""
echo "=== [5/5] Running Headless Gatekeeper ==="
bash tests/run.sh
