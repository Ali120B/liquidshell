#!/usr/bin/env bash
# matugen.sh — theme kitty/foot/waybar/fastfetch/hyprland/dunst on wallpaper change
set -euo pipefail
WALL="$1"
[[ -f "$WALL" ]] || exit 0
# NOTE: --prefer saturation picks the wallpaper's dominant hue (e.g. green stays
# green). --prefer darkness biased toward dark tones and washed hues out to blue.
matugen image "$WALL" --prefer saturation -m dark >/dev/null 2>&1 || matugen image "$WALL" --prefer saturation >/dev/null 2>&1 || true
# Hyprland: strip # (scheme expects without #)
if [[ -f "$HOME/.config/hypr/scheme/current.lua" ]]; then
  sed -i 's/"#\([0-9a-fA-F]\{6\}\)"/"\1"/g' "$HOME/.config/hypr/scheme/current.lua" 2>/dev/null || true
fi
# Foot: strip # (expects RRGGBB)
if [[ -f "$HOME/.config/foot/colors.ini" ]]; then
  sed -i 's/#//g' "$HOME/.config/foot/colors.ini" 2>/dev/null || true
fi
if [[ -f "$HOME/.config/hypr/scheme/current.lua" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  primary=$(grep -oP 'primary = "\K[0-9a-fA-F]+' "$HOME/.config/hypr/scheme/current.lua" 2>/dev/null | head -n 1)
  onsv=$(grep -oP 'onSurfaceVariant = "\K[0-9a-fA-F]+' "$HOME/.config/hypr/scheme/current.lua" 2>/dev/null | head -n 1)
  if [[ -n "$primary" && -n "$onsv" ]]; then
    hyprctl eval "hl.config({ general = { col = { active_border = \"rgba(${primary}e6)\", inactive_border = \"rgba(${onsv}11)\" } } })" >/dev/null 2>&1 || true
  fi
fi
pkill -SIGUSR1 -x kitty 2>/dev/null || true
pkill -SIGUSR1 -x foot 2>/dev/null || true
pkill -SIGUSR2 -x waybar 2>/dev/null || (pkill waybar 2>/dev/null; nohup waybar >/dev/null 2>&1 & disown)
# NOTE: SIGUSR1 pauses / SIGUSR2 unpauses dunst — neither reloads config.
# dunstctl reload is the only way to pick up the regenerated dunstrc.
dunstctl reload 2>/dev/null || (pkill dunst 2>/dev/null; nohup dunst >/dev/null 2>&1 & disown)
notify-send "Theme updated" "$(basename "$WALL")" -a matugen 2>/dev/null & disown || true
