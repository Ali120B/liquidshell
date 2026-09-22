#!/usr/bin/env bash
# volume.sh — wpctl + OSD
set -euo pipefail
case "${1:-}" in
  up) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ 2>/dev/null || true ;;
  down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- 2>/dev/null || true ;;
  mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || true ;;
esac
# Get volume 0-100 and show OSD
vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -oP '\d+\.\d+' | awk '{print int($1*100)}' 2>/dev/null || echo 0)
# Clamp
if [[ "$vol" -gt 100 ]]; then vol=100; fi
quickshell ipc -p ~/.config/quickshell call osd showVolume "$vol" 2>/dev/null || true
