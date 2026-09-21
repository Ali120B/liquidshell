#!/usr/bin/env bash
# matugen.sh — theme kitty/foot/waybar/fastfetch/hyprland on wallpaper change
set -euo pipefail
WALL="$1"
[[ -f "$WALL" ]] || exit 0
# Use darkness preference for consistent dark theme
matugen image "$WALL" --prefer darkness -m dark >/dev/null 2>&1 || matugen image "$WALL" --prefer darkness >/dev/null 2>&1 || true
# Post-process hyprland scheme to strip # if needed (matugen outputs with #, but scheme expects without)
if [[ -f "$HOME/.config/hypr/scheme/current.lua" ]]; then
  # Keep both with and without # handling — just ensure it has quotes
  sed -i 's/"#\([0-9a-fA-F]\{6\}\)"/"\1"/g' "$HOME/.config/hypr/scheme/current.lua" 2>/dev/null || true
  # Live-apply hyprland borders
  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    primary=$(grep -oP 'primary = "\K[0-9a-fA-F]+' "$HOME/.config/hypr/scheme/current.lua" 2>/dev/null | head -n 1)
    onsv=$(grep -oP 'onSurfaceVariant = "\K[0-9a-fA-F]+' "$HOME/.config/hypr/scheme/current.lua" 2>/dev/null | head -n 1)
    [[ -n "$primary" && -n "$onsv" ]] && hyprctl eval "hl.config({ general = { col = { active_border = \"rgba(${primary}e6)\", inactive_border = \"rgba(${onsv}11)\" } } })" >/dev/null 2>&1 || true
  fi
fi
pkill -SIGUSR1 -x kitty 2>/dev/null || true
pkill -SIGUSR2 -x waybar 2>/dev/null || (pkill waybar 2>/dev/null; nohup waybar >/dev/null 2>&1 & disown)
# foot and fastfetch pick up on next launch, no reload needed
notify-send "Theme updated" "$(basename "$WALL")" -a matugen 2>/dev/null & disown || true
