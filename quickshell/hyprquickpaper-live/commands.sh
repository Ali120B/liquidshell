#!/usr/bin/env bash
# Live wallpaper switcher: video via mpvpaper, gif/image via awww.
# Kills the previous live wallpaper first so they never stack.
FILE="$1"

# Remember choice so it can be restored after reboot
mkdir -p "$HOME/.cache/quickshell"
echo "$FILE" > "$HOME/.cache/quickshell/last-live-wallpaper"

# Kill any running video wallpaper
pkill -f "mpvpaper" 2>/dev/null

case "$FILE" in
    *.mp4|*.MP4|*.webm|*.WEBM|*.mkv|*.MKV|*.mov|*.MOV)
        # Clear static layer so video shows through, brief beat like a transition
        awww clear 2>/dev/null
        sleep 0.3
        # nice +5 so browser/YT wins the CPU fight; framedrop keeps it smooth
        nice -n 5 mpvpaper -o "loop --mute=yes --hwdec=auto --framedrop=vo" '*' "$FILE" &
        ;;
    *)
        # gif / image: same cool random transition as the static picker
        awww img "$FILE" -t random --transition-duration 1 &
        ;;
esac
