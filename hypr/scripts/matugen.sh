#!/usr/bin/env bash
# matugen.sh — theme kitty/foot/waybar/fastfetch/hyprland/dunst on wallpaper change
set -euo pipefail
WALL="$1"
[[ -f "$WALL" ]] || exit 0
# Videos/gifs: NEVER feed the whole file to matugen/magick — they decode every
# frame into RAM (up to ~10GB). Snapshot one small frame and theme from that.
SRC="$WALL"
case "$WALL" in
  *.mp4|*.MP4|*.webm|*.WEBM|*.mkv|*.MKV|*.mov|*.MOV|*.gif|*.GIF)
    SNAP="$(mktemp /tmp/matugen-frame-XXXXXX.jpg)"
    trap 'rm -f "$SNAP"' EXIT
    if command -v ffmpeg >/dev/null 2>&1 \
      && ffmpeg -y -loglevel error -i "$WALL" -vframes 1 -vf "scale=320:-1" "$SNAP" 2>/dev/null \
      && [[ -s "$SNAP" ]]; then
      SRC="$SNAP"
    else
      SRC="" # snapshot failed -> neutral fallback below
    fi
    ;;
esac
# NOTE: --prefer saturation picks the wallpaper's dominant hue (e.g. green stays
# green). --prefer darkness biased toward dark tones and washed hues out to blue.
# BUT near-monochrome wallpapers (e.g. pure black, sat ~0) have no hue to keep,
# so saturation preference grabs a random vivid color (usually blue). Detect
# that case and theme from neutral gray instead.
if [[ -z "$SRC" ]]; then
  matugen color hex "#8b9198" -m dark -t scheme-monochrome >/dev/null 2>&1 || true
  SRC="$WALL" # reloads below still run; theming already done, skip re-theme
  SKIP_THEME=1
else
  SKIP_THEME=0
fi
if [[ "$SKIP_THEME" -eq 0 ]]; then
SAT=$(magick "$SRC" -colorspace HSL -channel S -separate +channel -format "%[fx:mean]" info: 2>/dev/null || echo 1)
if awk "BEGIN {exit !(($SAT + 0) < 0.08)}"; then
  # Monochrome: tonal-spot from gray still invents blue, monochrome stays neutral.
  matugen color hex "#8b9198" -m dark -t scheme-monochrome >/dev/null 2>&1 || true
else
  matugen image "$SRC" --prefer saturation -m dark >/dev/null 2>&1 || matugen image "$SRC" --prefer saturation >/dev/null 2>&1 || true
fi
fi
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
    hyprctl eval "hl.config({ general = { col = { active_border = \"rgba(${primary}99)\", inactive_border = \"rgba(${onsv}11)\" } } })" >/dev/null 2>&1 || true
  fi
fi
pkill -SIGUSR1 -x kitty 2>/dev/null || true
pkill -SIGUSR1 -x foot 2>/dev/null || true
pkill -SIGUSR2 -x waybar 2>/dev/null || (pkill waybar 2>/dev/null; nohup waybar >/dev/null 2>&1 & disown)
# NOTE: SIGUSR1 pauses / SIGUSR2 unpauses dunst — neither reloads config.
# dunstctl reload is the only way to pick up the regenerated dunstrc.
dunstctl reload 2>/dev/null || (pkill dunst 2>/dev/null; nohup dunst >/dev/null 2>&1 & disown)
notify-send "Theme updated" "$(basename "$WALL")" -a matugen 2>/dev/null & disown || true
