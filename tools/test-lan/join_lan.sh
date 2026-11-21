#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: bash tools/test-lan/join_lan.sh <HOST_IP> [PORT]"
  exit 1
fi

HOST_IP="$1"
PORT="${2:-7777}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-$HOME/.local/bin/godot}"

if [[ ! -x "$GODOT" ]]; then
  GODOT="$(command -v godot || true)"
fi

if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
  echo "ERROR: Godot executable not found. Set GODOT=/path/to/godot or install godot in PATH." >&2
  exit 2
fi

WSL_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
echo "[NET] Target host: $HOST_IP:$PORT"
echo "[NET] Local WSL2 IP: ${WSL_IP:-unknown}"

if command -v ipconfig.exe >/dev/null 2>&1; then
  WIN_WLAN_IP="$(timeout 2 ipconfig.exe </dev/null 2>/dev/null | tr -d '\r' | awk '/Wireless LAN adapter WLAN:/,/^$/' | grep -E "IPv4" || true)"
  if [[ -n "$WIN_WLAN_IP" ]]; then
    echo "[NET] Windows WLAN: $WIN_WLAN_IP"
  fi
fi

if ping -c 1 -W 1 "$HOST_IP" >/dev/null 2>&1; then
  echo "[NET] ICMP ping to $HOST_IP succeeded."
else
  echo "[NET] ICMP ping to $HOST_IP did not reply (common with Windows Firewall; proceeding to UDP)."
fi

AUDIO_ARGS=()
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  AUDIO_ARGS=(--audio-driver Dummy)
fi

echo "[CLIENT] Launching kalastuspeli client -> $HOST_IP:$PORT ..."
"$GODOT" ${AUDIO_ARGS[@]+"${AUDIO_ARGS[@]}"} --path "$PROJECT_DIR" -- --env test --join "$HOST_IP" --port "$PORT"
