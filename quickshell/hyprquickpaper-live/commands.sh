#!/usr/bin/env bash
# Live wallpaper switcher: video via mpvpaper (kept), image via hyprpaper (0% idle).
FILE="$1"

mkdir -p "$HOME/.cache/quickshell"
echo "$FILE" > "$HOME/.cache/quickshell/last-live-wallpaper"

pkill -f "mpvpaper" 2>/dev/null

case "$FILE" in
    *.mp4|*.MP4|*.webm|*.WEBM|*.mkv|*.MKV|*.mov|*.MOV)
        # Unload hyprpaper so video shows through
        hyprctl hyprpaper unload all 2>/dev/null || true
        sleep 0.2
        nice -n 5 mpvpaper -o "loop --mute=yes --hwdec=auto --framedrop=vo" '*' "$FILE" &
        bash "$HOME/.config/hypr/scripts/matugen.sh" "$FILE" 2>/dev/null & disown || true
        ;;
    *)
        hyprctl hyprpaper wallpaper ",$FILE" 2>/dev/null || hyprctl hyprpaper wallpaper "eDP-1,$FILE" 2>/dev/null || true
        bash "$HOME/.config/hypr/scripts/matugen.sh" "$FILE" 2>/dev/null & disown || true
        ;;
esac
