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
    local out
    # Single hyprctl + jq: empty => no window => play, else check floating/fullscreen
    out=$(hyprctl activewindow -j 2>/dev/null | jq -r 'if (.address // empty) == "" then "play" elif (.fullscreen // 0) != 0 or (.floating // false) == false then "stop" else "play" end' 2>/dev/null) || { echo play; return; }
    # jq returns play/stop directly, fallback to play on empty
    [[ -n "$out" ]] && echo "$out" || echo play
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
    # Only poll Hyprland when a live wallpaper is actually running
    if ! is_video_live; then
        sleep 5
        continue
    fi
    apply "$(decide)"
    sleep 2
done
