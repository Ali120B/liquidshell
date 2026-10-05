#!/usr/bin/env bash
# wallpaper-theme.sh — keep the matugen theme in sync with the active wallpaper.
# Wallpaper switchers don't hook matugen, so without this the theme goes stale
# ("stuck" on whatever wallpaper was active at login).
# Usage: wallpaper-theme.sh --current  (re-theme once from active wallpaper)
#        wallpaper-theme.sh --watch    (poll every 5s, re-theme on change)
set -uo pipefail

current_wallpaper() {
    local wall=""
    # 1. hyprpaper active wallpaper (format: "MON: /path/to/wall")
    wall=$(hyprctl hyprpaper listactive 2>/dev/null | head -n 1 | sed 's/^[^:]*:[[:space:]]*//')
    if [[ -n "$wall" && -f "$wall" ]]; then echo "$wall"; return 0; fi
    # 2. quickshell / live-wallpaper cache (covers video wallpapers via mpvpaper)
    wall=$(cat "$HOME/.cache/quickshell/last-live-wallpaper" 2>/dev/null || true)
    [[ -f "$wall" ]] && echo "$wall" && return 0
    return 1
}

case "${1:---current}" in
    --current)
        wall=$(current_wallpaper) || exit 0
        bash "$HOME/.config/hypr/scripts/matugen.sh" "$wall" 2>/dev/null & disown || true
        ;;
    --watch)
        # Let restore-wallpaper.sh finish its login apply + theme first.
        sleep 15
        last=""
        while true; do
            if wall=$(current_wallpaper); then
                if [[ "$wall" != "$last" ]]; then
                    last="$wall"
                    bash "$HOME/.config/hypr/scripts/matugen.sh" "$wall" 2>/dev/null & disown || true
                fi
            fi
            sleep 5
        done
        ;;
    *) echo "usage: wallpaper-theme.sh [--current|--watch]" >&2; exit 1 ;;
esac
