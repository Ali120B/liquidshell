#!/usr/bin/env bash
# Show keybind cheatsheet in a rofi window themed to match the rice
rofi -dmenu \
    -theme "$HOME/.config/rofi/cheatsheet.rasi" \
    -markup-rows \
    -no-custom \
    -p "" \
    -lines 40 \
    < "$HOME/.config/hypr/scripts/cheatsheet.txt"