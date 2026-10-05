#!/usr/bin/env bash
# power-profile.sh — cycle power-profiles-daemon profiles + quickshell OSD.
# Usage: power-profile.sh [up|down|next|show]
# Order: power-saver -> balanced -> performance (wraps around).
set -uo pipefail

PROFILES=(power-saver balanced performance)

cur=$(powerprofilesctl get 2>/dev/null || echo "balanced")
idx=-1
for i in "${!PROFILES[@]}"; do
    [[ "${PROFILES[$i]}" == "$cur" ]] && idx=$i && break
done
[[ $idx -eq -1 ]] && idx=1 # unknown current -> treat as balanced

# Clamped, no wrap: up/next stop at performance, down/prev at power-saver.
case "${1:-next}" in
    up|next)   [[ $idx -lt 2 ]] && idx=$((idx + 1)) ;;
    down|prev) [[ $idx -gt 0 ]] && idx=$((idx - 1)) ;;
    show) ;;
    *) echo "usage: power-profile.sh [up|down|next|show]" >&2; exit 1 ;;
esac

if [[ "${1:-next}" != "show" ]]; then
    powerprofilesctl set "${PROFILES[$idx]}" 2>/dev/null || true
fi
# Cache for the starship prompt (instant read, no D-Bus wait per render).
powerprofilesctl get 2>/dev/null > ~/.cache/power-profile || true
quickshell ipc -p ~/.config/quickshell call osd showPowerProfile "${PROFILES[$idx]}" 2>/dev/null || true
