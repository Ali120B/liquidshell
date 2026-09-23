#!/usr/bin/env bash
# volume.sh — wpctl + OSD
set -euo pipefail
case "${1:-}" in
  up) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ 2>/dev/null || true ;;
  down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- 2>/dev/null || true ;;
  mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || true ;;
esac
# Get volume 0-100 + mute flag and show OSD
out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "0.00")
vol=$(echo "$out" | grep -oP '\d+\.\d+' | awk '{print int($1*100)}' 2>/dev/null || echo 0)
# Clamp
if [[ "$vol" -gt 100 ]]; then vol=100; fi
muted=0
echo "$out" | grep -q "MUTED" && muted=1
quickshell ipc -p ~/.config/quickshell call osd showVolume "$vol" "$muted" 2>/dev/null || true
