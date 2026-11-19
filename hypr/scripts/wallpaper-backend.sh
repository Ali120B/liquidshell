#!/usr/bin/env bash
# wallpaper-backend.sh — start the wallpaper backend chosen by install.sh.
# Skwd Wall restores its own wallpaper via skwd-walld, so hyprpaper must not
# start (it would flash the old hyprpaper wallpaper at login).
set -u

choice=$(cat "$HOME/.config/hypr/.wallpaper-picker" 2>/dev/null || true)

if [[ "$choice" == "legacy" ]] || ! command -v skwd-helm >/dev/null 2>&1; then
    hyprpaper &
    bash "$HOME/.config/hypr/scripts/restore-wallpaper.sh" &
else
    # Clear anything left over from the legacy backend.
    pkill -x hyprpaper 2>/dev/null || true
    pkill -f '[m]pvpaper' 2>/dev/null || true
fi
