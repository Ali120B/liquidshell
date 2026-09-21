#!/usr/bin/env bash
# Auto-pause live wallpaper (skwd) when a non-floating window is focused.
# PAUSE when active window is tiled or fullscreen, RESUME when on empty desktop
# or only a floating window is focused. Matches old mpvpaper autopause logic.
# Polls every 2s, uses skwd-helm pause/resume (idempotent).

decide() {
    local json addr floating fullscreen
    json=$(hyprctl activewindow -j 2>/dev/null) || { echo play; return; }
    addr=$(echo "$json" | jq -r '.address // empty')
    if [[ -z "$addr" ]]; then
        echo play
        return
    fi
    floating=$(echo "$json" | jq -r '.floating // false')
    fullscreen=$(echo "$json" | jq -r '.fullscreen // 0')
    if [[ "$fullscreen" != "0" || "$floating" == "false" ]]; then
        echo stop
    else
        echo play
    fi
}

is_video_wallpaper() {
    # Check if current wallpaper is a video/live type
    local type
    type=$(skwd-helm current --json 2>/dev/null | jq -r '.outputs[0].type // empty')
    [[ "$type" == "video" || "$type" == "we" ]]
}

apply() {
    local want="$1"
    is_video_wallpaper || return
    if [[ "$want" == "stop" ]]; then
        skwd-helm pause >/dev/null 2>&1 || true
    else
        skwd-helm resume >/dev/null 2>&1 || true
    fi
}

while true; do
    apply "$(decide)"
    sleep 2
done
