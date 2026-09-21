#!/usr/bin/env bash
# Restores last wallpaper on login: live video via mpvpaper, image via hyprpaper (0% idle).
# On-demand: only starts mpvpaper if last was video; hyprpaper is started by Hyprland.
sleep 1

LAST=$(cat "$HOME/.cache/quickshell/last-live-wallpaper" 2>/dev/null)

start_video() {
    hyprctl hyprpaper unload all 2>/dev/null || true
    sleep 0.2
    nice -n 5 mpvpaper -o "loop --mute=yes --hwdec=auto --framedrop=vo" '*' "$1" &
}

case "$LAST" in
    *.mp4|*.MP4|*.webm|*.WEBM|*.mkv|*.MKV|*.mov|*.MOV)
        [[ -f "$LAST" ]] && { start_video "$LAST"; exit 0; } ;;
    *.gif|*.GIF|*.png|*.PNG|*.jpg|*.JPG|*.jpeg|*.JPEG|*.webp|*.WEBP)
        [[ -f "$LAST" ]] && { pkill -f "[m]pvpaper" 2>/dev/null; hyprctl hyprpaper wallpaper ",$LAST" 2>/dev/null || hyprctl hyprpaper wallpaper "eDP-1,$LAST" 2>/dev/null || true; exit 0; } ;;
esac

# Fallback: last not set or missing — try /home/wallpaper first, then Pictures
for try in "/home/wallpaper/0002.jpg" "$HOME/Pictures/Wallpapers/0002.jpg" "$HOME/Pictures/wallpaper.jpg"; do
    [[ -f "$try" ]] && { hyprctl hyprpaper wallpaper ",$try" 2>/dev/null || true; exit 0; }
done
