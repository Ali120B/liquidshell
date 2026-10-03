#!/usr/bin/env bash
# lock.sh — screen lock wrapper.
# Pauses video wallpapers while locked, resumes on unlock.
# Hyprlock runs in the foreground and exits on unlock, so resume always runs.
# No `set -e`: resume must run even if pause (or the daemon) fails.
#
# Dusky 001_dusky theme reads a static file at ~/.cache/current_wallpaper,
# so snapshot the active wallpaper there before locking. Wallpaper sources
# tried in order: hyprpaper active -> quickshell last-live-wallpaper cache.

cache_wallpaper() {
    local wall=""
    # 1. hyprpaper active wallpaper (format: "MON: /path/to/wall")
    wall=$(hyprctl hyprpaper listactive 2>/dev/null | head -n 1 | sed 's/^[^:]*:[[:space:]]*//' || true)
    if [[ -z "$wall" || ! -f "$wall" ]]; then
        # 2. quickshell / live-wallpaper cache
        wall=$(cat "$HOME/.cache/quickshell/last-live-wallpaper" 2>/dev/null || true)
    fi
    [[ -f "$wall" ]] || return 0
    case "$wall" in
        *.mp4|*.MP4|*.webm|*.WEBM|*.mkv|*.MKV|*.mov|*.MOV|*.gif|*.GIF)
            # Video: snapshot one frame so hyprlock gets a static image.
            # Never copy the whole video — hyprlock expects an image.
            ffmpeg -y -loglevel error -i "$wall" -vframes 1 "$HOME/.cache/current_wallpaper" 2>/dev/null || cp "$wall" "$HOME/.cache/current_wallpaper" 2>/dev/null || true
            ;;
        *)
            cp "$wall" "$HOME/.cache/current_wallpaper" 2>/dev/null || true
            ;;
    esac
}

skwd-helm pause 2>/dev/null
cache_wallpaper
hyprlock
skwd-helm resume 2>/dev/null
