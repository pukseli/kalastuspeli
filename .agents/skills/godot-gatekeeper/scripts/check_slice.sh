#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$PROJECT_DIR"

echo "=== [1/3] Checking Slice Spec Line Limits (<= 60 non-empty lines) ==="
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

if [ "$VIOLATIONS" -gt 0 ]; then
  echo "Spec line limit violation! Split the slice according to 00-architecture.md §5."
  exit 1
fi

echo ""
echo "=== [2/3] Checking Test Immutability (Uncommitted Test Edits) ==="
if [ "${CHECK_TEST_DIFF:-0}" = "1" ]; then
  DIFF_TESTS=$(git diff --name-only tests/test_*.gd || true)
  if [ -n "$DIFF_TESTS" ]; then
    echo "[WARN] Acceptance tests modified in working tree:"
    echo "$DIFF_TESTS"
  else
    echo "[OK] No acceptance tests modified."
  fi
else
  echo "[SKIP] Test diff check skipped (set CHECK_TEST_DIFF=1 to enable)."
fi

echo ""
echo "=== [3/3] Running Headless Gatekeeper ==="
bash tests/run.sh
