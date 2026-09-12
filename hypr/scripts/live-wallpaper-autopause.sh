#!/usr/bin/env bash
# Auto-pause live video wallpaper when a non-floating app is focused.
# STOP (0% CPU, frozen frame) when active window is tiled or fullscreen,
# CONT when on empty desktop or only a floating window is focused.
# No mpvpaper running (static wallpaper) -> does nothing.
# Polls every 2s: simple, no IPC socket quirks, negligible cost.

STOPPED=0

is_video_live() {
    pgrep -f "[m]pvpaper" >/dev/null
}

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

apply() {
    local want="$1"
    is_video_live || return
    # Both signals are idempotent, so no state tracking: picker switches
    # that kill/restart mpvpaper can never desync this.
    if [[ "$want" == "stop" ]]; then
        pkill -STOP -f "[m]pvpaper"
    else
        pkill -CONT -f "[m]pvpaper"
    fi
}

while true; do
    apply "$(decide)"
    sleep 2
done
