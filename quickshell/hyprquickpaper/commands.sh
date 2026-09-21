pkill -f "mpvpaper" 2>/dev/null
# Remember choice so login restore picks static, not a stale video
mkdir -p "$HOME/.cache/quickshell"
echo "$1" > "$HOME/.cache/quickshell/last-live-wallpaper"
# hyprpaper is 0% idle, instant — no awww daemon
hyprctl hyprpaper wallpaper ",$1" 2>/dev/null || hyprctl hyprpaper wallpaper "eDP-1,$1" 2>/dev/null || true
bash "$HOME/.config/hypr/scripts/matugen.sh" "$1" 2>/dev/null & disown || true
