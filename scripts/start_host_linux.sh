#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-7777}"
SYNC_HZ="${2:-20}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$HOME/.local/bin/godot}"

if [[ ! -x "$GODOT" ]]; then
  GODOT="$(command -v godot || true)"
fi

if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
  echo "ERROR: Godot executable not found. Set GODOT=/path/to/godot or install godot in PATH." >&2
  exit 2
fi

echo "=== Host LAN IPv4 Addresses ==="
if command -v ip >/dev/null 2>&1; then
  ip -4 -br addr 2>/dev/null || hostname -I
else
  hostname -I
fi

TOP_IP=""
if command -v ip >/dev/null 2>&1; then
  TOP_IP="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)"
fi
if [[ -z "$TOP_IP" ]]; then
  TOP_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi
if [[ -z "$TOP_IP" ]]; then
  TOP_IP="<HOST_IP>"
fi

echo ""
echo "Reminder: Ensure inbound UDP port $PORT is allowed in your firewall (ufw/firewalld)."
echo "Laptop join command:"
echo "  bash scripts/join_lan.sh $TOP_IP $PORT"
echo ""
echo "[HOST] Starting kalastuspeli host on UDP *:$PORT (sync: $SYNC_HZ Hz)..."
"$GODOT" --path "$PROJECT_DIR" -- --host --port "$PORT" --sync-hz "$SYNC_HZ"
