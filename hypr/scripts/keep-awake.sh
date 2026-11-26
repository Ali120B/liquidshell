#!/usr/bin/env bash
# keep-awake.sh — Waybar keep-awake toggle.
# Blocks logind's idle hint while the screen is on, so hypridle won't blank/lock.
# It intentionally does NOT block sleep: if the screen is already off, it doesn't count.
set -u

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/keep-awake"
PID_FILE="$STATE_DIR/pid"
mkdir -p "$STATE_DIR"

is_active() {
    [[ -f "$PID_FILE" ]] || return 1
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null) || return 1
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

screen_on() {
    hyprctl monitors -j 2>/dev/null | jq -e 'any(.[]; .dpmsStatus == true)' >/dev/null 2>&1
}

start() {
    is_active && return 0
    # If the panel is already down, this toggle doesn't count.
    screen_on || return 0
    systemd-inhibit --what=idle --mode=block \
        --who="Waybar keep awake" --why="Keep the screen on" \
        sleep infinity >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
}

stop() {
    if is_active; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
}

status() {
    if is_active; then
        printf '{"text":"󰥔","tooltip":"Keep awake: on (screen only)","class":"active"}\n'
    else
        printf '{"text":"󰥔","tooltip":"Keep awake: off","class":"inactive"}\n'
    fi
}

case "${1:-status}" in
    toggle) if is_active; then stop; else start; fi ;;
    status) status ;;
    *) status ;;
esac