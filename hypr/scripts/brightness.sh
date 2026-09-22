#!/usr/bin/env bash
# brightness.sh — brightnessctl + OSD
set -euo pipefail
case "${1:-}" in
  up) brightnessctl set 5%+ 2>/dev/null || true ;;
  down) brightnessctl set 5%- 2>/dev/null || true ;;
esac
bri=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%' | head -n1 2>/dev/null || echo 0)
# Fallback via brightnessctl g
if [[ -z "$bri" || "$bri" == "0" ]]; then
  bri=$(brightnessctl g 2>/dev/null | head -n1 || echo 0)
  max=$(brightnessctl m 2>/dev/null | head -n1 || echo 100)
  if [[ "$max" -gt 0 ]]; then bri=$(( bri * 100 / max )); fi
fi
bri=$(printf "%.0f" "$bri" 2>/dev/null || echo 0)
quickshell ipc -p ~/.config/quickshell call osd showBrightness "$bri" 2>/dev/null || true
