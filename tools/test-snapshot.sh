#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT="whale_strike_2s"
if [[ $# -ge 1 && "${1:-}" != --* ]]; then
  SNAPSHOT="$1"
  shift
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$HOME/.local/bin/godot}"

if [[ ! -x "$GODOT" ]]; then
  GODOT="$(command -v godot || true)"
fi

if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
  echo "ERROR: Godot executable not found. Set GODOT=/path/to/godot or install godot in PATH." >&2
  exit 2
fi

AUDIO_ARGS=()
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  AUDIO_ARGS=(--audio-driver Dummy)
fi

echo "[SNAPSHOT] Launching kalastuspeli with test snapshot: $SNAPSHOT"
"$GODOT" ${AUDIO_ARGS[@]+"${AUDIO_ARGS[@]}"} --path "$PROJECT_DIR" -- --env test --snapshot "$SNAPSHOT" "$@"
