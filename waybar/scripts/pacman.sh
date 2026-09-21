#!/usr/bin/env bash
# pacman updates check — runs every 3600s via waybar
# Shows pending updates count, 0% CPU when idle
set -uo pipefail
if ! command -v checkupdates &>/dev/null && ! command -v yay &>/dev/null; then
  echo '{"text":"","class":"hidden","tooltip":"no checker"}'
  exit 0
fi
# Use checkupdates or yay -Qu
updates=0
if command -v checkupdates &>/dev/null; then
  updates=$(checkupdates 2>/dev/null | wc -l)
elif command -v yay &>/dev/null; then
  updates=$(yay -Qu 2>/dev/null | wc -l)
fi
updates=$(echo "$updates" | tr -d ' ')
if [[ "$updates" -eq 0 || -z "$updates" ]]; then
  echo '{"text":"󰏔 0","class":"pacman-ok","tooltip":"System up to date"}'
else
  echo "{\"text\":\"󰏔 $updates\",\"class\":\"pacman-updates\",\"tooltip\":\"$updates updates available (click to update)\"}"
fi
