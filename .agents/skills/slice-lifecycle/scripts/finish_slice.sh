#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$PROJECT_DIR"

SLICE_NUM="${1:-}"
COMMIT_MSG="${2:-}"

if [ -z "$SLICE_NUM" ]; then
  echo "Usage: $0 <slice-num> [commit-message]"
  echo "Example: $0 04 \"add station interaction and helm occupation\""
  exit 1
fi

echo "=== Verifying Gatekeeper & Spec limits ==="
bash .agents/skills/godot-gatekeeper/scripts/check_slice.sh

echo ""
echo "=== Checking Git Status ==="
git status --short

if [ -n "$COMMIT_MSG" ]; then
  echo ""
  echo "=== Creating Commit and Pushing ==="
  git add .
  git commit -m "feat(slice-${SLICE_NUM}): ${COMMIT_MSG}"
  git push origin main
  echo "[DONE] Committed and pushed feat(slice-${SLICE_NUM}): ${COMMIT_MSG}"
else
  echo ""
  echo "[INFO] Verification passed! To commit and push, run:"
  echo "git commit -m \"feat(slice-${SLICE_NUM}): <message>\" && git push origin main"
fi
