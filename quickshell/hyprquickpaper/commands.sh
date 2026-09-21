pkill -f "mpvpaper" 2>/dev/null
# Remember choice so login restore picks static, not a stale video
mkdir -p "$HOME/.cache/quickshell"
echo "$1" > "$HOME/.cache/quickshell/last-live-wallpaper"
awww img "$1" -t random --transition-duration 1
