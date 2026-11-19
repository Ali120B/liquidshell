#!/usr/bin/env bash
# wallpaper-theme.sh — keep the matugen theme in sync with the active wallpaper.
# Supports Skwd Wall v2, hyprpaper and the legacy quickshell/live-wallpaper cache.
# Usage: wallpaper-theme.sh --current  (re-theme once from active wallpaper)
#        wallpaper-theme.sh --watch    (poll every 5s, re-theme on change)
set -uo pipefail

skwd_current_wallpaper() {
    command -v skwd-helm >/dev/null 2>&1 || return 1

    local json key path img preview item
    json=$(skwd-helm current --json 2>/dev/null) || return 1
    key=$(printf '%s\n' "$json" | jq -r '.outputs[]? | select(.current != null and .current != "") | .current' 2>/dev/null | head -n 1)
    path=$(printf '%s\n' "$json" | jq -r '.outputs[]? | select(.path != null and .path != "") | .path' 2>/dev/null | head -n 1)

    # Wallpaper Engine reports only its scene key; resolve it through the library.
    if [[ -z "$path" && -n "$key" ]]; then
        item=$(skwd-helm list --json 2>/dev/null \
            | jq -r --arg k "$key" '
                .wallpapers[]? | select(
                    .key == $k or .key == ("we:" + $k) or
                    (.path != null and (.path | endswith("/" + $k)))
                ) | [.path, .preview] | @tsv' 2>/dev/null | head -n 1)
        if [[ -n "$item" ]]; then
            path=${item%%$'\t'*}
            preview=${item#*$'\t'}
        fi
    fi

    # Static image or video file.
    if [[ -n "$path" && -f "$path" ]]; then printf '%s\n' "$path"; return 0; fi

    # Wallpaper Engine scene: use a preview/cover image inside the scene folder.
    if [[ -n "$path" && -d "$path" ]]; then
        img=$(find "$path" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            2>/dev/null | head -n 1)
        [[ -n "$img" ]] && { printf '%s\n' "$img"; return 0; }
    fi

    # Final fallback: skwd's generated preview for this wallpaper key.
    if [[ -n "$key" ]]; then
        preview=$(skwd-helm list --json 2>/dev/null \
            | jq -r --arg k "$key" '.wallpapers[]? | select(.key == $k) | .preview // empty' 2>/dev/null \
            | head -n 1)
        [[ -n "$preview" && -f "$preview" ]] && { printf '%s\n' "$preview"; return 0; }
    fi

    return 1
}

current_wallpaper() {
    local wall=""

    # 1. Skwd Wall v2 (preferred when it has an applied wallpaper).
    if wall=$(skwd_current_wallpaper); then echo "$wall"; return 0; fi

    # 2. hyprpaper active wallpaper (format: "MON: /path/to/wall").
    wall=$(hyprctl hyprpaper listactive 2>/dev/null | head -n 1 | sed 's/^[^:]*:[[:space:]]*//')
    if [[ -n "$wall" && -f "$wall" ]]; then echo "$wall"; return 0; fi

    # 3. Legacy quickshell / live-wallpaper cache (video wallpapers via mpvpaper).
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
        # First poll fires immediately so a restored wallpaper gets themed once,
        # then only actual wallpaper changes trigger matugen.
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
