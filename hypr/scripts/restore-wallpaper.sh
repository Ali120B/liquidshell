#!/usr/bin/env bash
# Restores last wallpaper on login: live video via mpvpaper,
# gif/image via awww, fallback to default static.
sleep 3 # let awww-daemon come up first

LAST=$(cat "$HOME/.cache/quickshell/last-live-wallpaper" 2>/dev/null)

start_video() {
    awww clear 2>/dev/null
    sleep 0.3
    nice -n 5 mpvpaper -o "loop --mute=yes --hwdec=auto --framedrop=vo" '*' "$1" &
}

case "$LAST" in
    *.mp4|*.MP4|*.webm|*.WEBM|*.mkv|*.MKV|*.mov|*.MOV)
        [[ -f "$LAST" ]] && { start_video "$LAST"; exit 0; } ;;
    *.gif|*.GIF|*.png|*.PNG|*.jpg|*.JPG|*.jpeg|*.JPEG)
        [[ -f "$LAST" ]] && { pkill -f "[m]pvpaper" 2>/dev/null; awww img "$LAST" -t random --transition-duration 1; exit 0; } ;;
esac

# Fallback: default static
awww img "$HOME/Pictures/wallpaper.jpg"
