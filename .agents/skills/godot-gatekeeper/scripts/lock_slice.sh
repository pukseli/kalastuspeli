#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$PROJECT_DIR"

LOCK_FILE=".agents/slice_lock.sha256"
ACTION="${1:-lock}"

case "$ACTION" in
  lock)
    FILES=()
    for f in tests/run.sh tests/run_tests.gd tests/test_*.gd specs/slices/*.md; do
      [[ "$f" == "specs/slices/_template.md" ]] && continue
      [ -f "$f" ] && FILES+=("$f")
    done

    if [ "${#FILES[@]}" -eq 0 ]; then
      echo "[FAIL] No test or slice spec files found to lock."
      exit 1
    fi

    mapfile -t SORTED_FILES < <(printf '%s\n' "${FILES[@]}" | LC_ALL=C sort -u)
    sha256sum "${SORTED_FILES[@]}" > "$LOCK_FILE"
    echo "[LOCKED] ${#SORTED_FILES[@]} files -> $LOCK_FILE"
    ;;
  --verify)
    if [ ! -f "$LOCK_FILE" ]; then
      echo "[INFO] No lock file present ($LOCK_FILE)."
      exit 0
    fi
    if sha256sum -c --quiet "$LOCK_FILE"; then
      COUNT=$(wc -l < "$LOCK_FILE")
      echo "[OK] SHA-256 lock verified ($COUNT files)."
    else
      echo "[FAIL] Locked test harness, acceptance test, or slice spec was modified!"
      sha256sum -c "$LOCK_FILE" || true
      echo "Revert builder edits or re-run 'bash .agents/skills/godot-gatekeeper/scripts/lock_slice.sh' if intentional."
      exit 1
    fi
    ;;
  --clear)
    if [ -f "$LOCK_FILE" ]; then
      rm -f "$LOCK_FILE"
      echo "[CLEARED] Removed $LOCK_FILE"
    else
      echo "[INFO] No lock file to clear."
    fi
    ;;
  *)
    echo "Usage: $0 [lock|--verify|--clear]"
    exit 2
    ;;
esac
