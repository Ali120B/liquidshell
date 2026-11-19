#!/usr/bin/env bash
# lock.sh — screen lock wrapper.
# Pauses video wallpapers while locked, resumes on unlock.
# Hyprlock runs in the foreground and exits on unlock, so resume always runs.
# No `set -e`: resume must run even if pause (or the daemon) fails.
#
# Dusky 001_dusky theme reads a static file at ~/.cache/current_wallpaper,
# so snapshot the active wallpaper there before locking. Wallpaper sources
# tried in order: Skwd Wall v2 -> hyprpaper -> quickshell cache.

# Never stack hyprlock instances: extra invocations (double-triggered by
# logind + keybinding) must exit, not race for the ext-session-lock. Losing
# instances die mid-PAM-conversation, and each death counts as a
# pam_faillock failure — which is what kept locking the account.
exec 9>"$HOME/.cache/hyprlock.lock"
if ! flock -n 9; then
    exit 0
fi
if pgrep -x hyprlock >/dev/null 2>&1; then
    exit 0
fi

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

    if [[ -n "$path" && -f "$path" ]]; then printf '%s\n' "$path"; return 0; fi
    if [[ -n "$path" && -d "$path" ]]; then
        img=$(find "$path" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            2>/dev/null | head -n 1)
        [[ -n "$img" ]] && { printf '%s\n' "$img"; return 0; }
    fi
    if [[ -n "$key" ]]; then
        preview=$(skwd-helm list --json 2>/dev/null \
            | jq -r --arg k "$key" '.wallpapers[]? | select(.key == $k) | .preview // empty' 2>/dev/null \
            | head -n 1)
        [[ -n "$preview" && -f "$preview" ]] && { printf '%s\n' "$preview"; return 0; }
    fi
    return 1
}

cache_wallpaper() {
    local wall=""
    wall=$(skwd_current_wallpaper) || true
    if [[ -z "$wall" || ! -f "$wall" ]]; then
        # hyprpaper active wallpaper (format: "MON: /path/to/wall")
        wall=$(hyprctl hyprpaper listactive 2>/dev/null | head -n 1 | sed 's/^[^:]*:[[:space:]]*//' || true)
    fi
    if [[ -z "$wall" || ! -f "$wall" ]]; then
        # quickshell / live-wallpaper cache
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

# --cache-only: refresh ~/.cache/current_wallpaper and exit (used for testing).
if [[ "${1:-}" == "--cache-only" ]]; then
    cache_wallpaper
    exit 0
fi

skwd-helm pause 2>/dev/null
cache_wallpaper
# --immediate-render / --no-fade-in: take the ext-session-lock without waiting
# for the blurred wallpaper. Combined with hypridle's inhibit_sleep=3 this
# keeps hyprlock well inside logind's 5s InhibitDelayMaxSec before suspend.
hyprlock --immediate-render --no-fade-in
skwd-helm resume 2>/dev/null
