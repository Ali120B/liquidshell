#!/usr/bin/env bash
# skwd-theme.sh — render the matugen templates from Skwd Wall's generated scheme.
# Skwd writes ~/.cache/skwd-wall-v2/scheme.json on every wallpaper change; this
# feeds that straight to matugen so apps retheme immediately instead of waiting
# for the 5s wallpaper-theme.sh poll.
set -uo pipefail

SCHEME="$HOME/.cache/skwd-wall-v2/scheme.json"
[[ -f "$SCHEME" ]] || exit 0
command -v matugen >/dev/null 2>&1 || exit 0

current_image() {
    local json key path item preview img
    json=$(skwd-helm current --json 2>/dev/null) || return 1
    path=$(printf '%s\n' "$json" | jq -r '.outputs[]? | select(.path != null and .path != "") | .path' 2>/dev/null | head -n 1)
    key=$(printf '%s\n' "$json" | jq -r '.outputs[]? | select(.current != null and .current != "") | .current' 2>/dev/null | head -n 1)

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

img=$(current_image || true)
tmp=$(mktemp /tmp/skwd-scheme-XXXXXX.json)
trap 'rm -f "$tmp"' EXIT

# hyprlock's template needs an {{image}}; skwd's scheme.json has no image field.
if [[ -n "$img" ]]; then
    jq --arg img "$img" '. + {image: $img}' "$SCHEME" > "$tmp"
else
    cp "$SCHEME" "$tmp"
fi

matugen json "$tmp" >/dev/null 2>&1 || exit 0

# Hyprland expects RRGGBB without '#', foot expects bare hex.
[[ -f "$HOME/.config/hypr/scheme/current.lua" ]] && \
    sed -i 's/"#\([0-9a-fA-F]\{6\}\)"/"\1"/g' "$HOME/.config/hypr/scheme/current.lua" 2>/dev/null || true
[[ -f "$HOME/.config/foot/colors.ini" ]] && \
    sed -i 's/#//g' "$HOME/.config/foot/colors.ini" 2>/dev/null || true

if [[ -f "$HOME/.config/hypr/scheme/current.lua" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    primary=$(grep -oP 'primary = "\K[0-9a-fA-F]+' "$HOME/.config/hypr/scheme/current.lua" 2>/dev/null | head -n 1)
    onsv=$(grep -oP 'onSurfaceVariant = "\K[0-9a-fA-F]+' "$HOME/.config/hypr/scheme/current.lua" 2>/dev/null | head -n 1)
    if [[ -n "$primary" && -n "$onsv" ]]; then
        hyprctl eval "hl.config({ general = { col = { active_border = \"rgba(${primary}AA)\", inactive_border = \"rgba(${onsv}22)\" } } })" >/dev/null 2>&1 || true
    fi
fi

pkill -SIGUSR1 -x kitty 2>/dev/null || true
pkill -SIGUSR1 -x foot 2>/dev/null || true
pkill -SIGUSR1 -x waybar 2>/dev/null || (pkill waybar 2>/dev/null; nohup waybar >/dev/null 2>&1 & disown)
dunstctl reload 2>/dev/null || (pkill dunst 2>/dev/null; nohup dunst >/dev/null 2>&1 & disown)