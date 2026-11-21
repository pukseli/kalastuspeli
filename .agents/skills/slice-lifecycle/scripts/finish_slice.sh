#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$PROJECT_DIR"

SLICE_NUM="${1:-}"
COMMIT_MSG="${2:-}"

if [ -z "$SLICE_NUM" ]; then
  echo "Usage: $0 <slice-num> [commit-message]"
  echo "Example: $0 05 \"add snapshot interpolation for smooth sync\""
  exit 1
fi

echo "=== [1/3] Verifying Gatekeeper, Boundaries & Locks ==="
bash .agents/skills/godot-gatekeeper/scripts/check_slice.sh

echo ""
echo "=== [2/3] Checking Git Status & Scope ==="
STATUS=$(git -c core.quotepath=false status --porcelain -uall)
if [ -z "$STATUS" ]; then
  echo "[INFO] Working tree is clean; nothing to commit."
  exit 0
fi
echo "$STATUS"

OUT_OF_SCOPE=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  path="${line:3}"
  path="${path##* -> }"
  if [[ ! "$path" =~ ^(src|tests|specs|config)/ ]]; then
    OUT_OF_SCOPE+=("$path")
  fi
done <<< "$STATUS"

if [ "${#OUT_OF_SCOPE[@]}" -gt 0 ] && [ "${ALLOW_EXTRA_FILES:-0}" != "1" ]; then
  echo ""
  echo "[FAIL] Out-of-scope files detected outside src/, tests/, specs/, config/:"
  printf '  - %s\n' "${OUT_OF_SCOPE[@]}"
  echo "Inspect/revert them, or re-run with ALLOW_EXTRA_FILES=1 if intentionally part of this slice."
  exit 1
fi

if [ -n "$COMMIT_MSG" ]; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [ "$BRANCH" != "main" ]; then
    echo "[FAIL] Expected branch 'main', currently on '$BRANCH'. Refusing to push."
    exit 1
  fi

  echo ""
  echo "=== [3/3] Creating Commit, Pushing & Clearing Lock ==="
  if [ "${ALLOW_EXTRA_FILES:-0}" = "1" ]; then
    git add -A
  else
    git add -A -- src tests specs config
  fi
  git diff --cached --stat
  git commit -m "feat(slice-${SLICE_NUM}): ${COMMIT_MSG}"
  git push origin main
  bash .agents/skills/godot-gatekeeper/scripts/lock_slice.sh --clear
  echo "[DONE] Committed and pushed feat(slice-${SLICE_NUM}): ${COMMIT_MSG}"
else
  echo ""
  echo "[INFO] Verification passed! To commit and push, run:"
  echo "bash .agents/skills/slice-lifecycle/scripts/finish_slice.sh ${SLICE_NUM} \"<message>\""
fi
