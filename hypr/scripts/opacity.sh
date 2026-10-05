#!/usr/bin/env bash
# Opacity menu (rofi) + blur toggle.
# "Off" flips blur on/off live (no reload). Percentages set window opacity.
BLUR=$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null | python3 -c "import json,sys;d=json.load(sys.stdin);v=d.get('int',d.get('bool',True));print(1 if v in (1,True) else 0)" 2>/dev/null || echo 1)

choice=$(printf "Off\n100%%\n90%%\n85%%\n80%%\n70%%\n60%%\n50%%\n40%%" | rofi -dmenu -p "Opacity / Blur")

case "$choice" in
    "Off")
        if [[ "$BLUR" == "1" ]]; then
            hyprctl eval "hl.config({ decoration = { blur = { enabled = false } } })" >/dev/null 2>&1
            notify-send "Blur" "off" 2>/dev/null &
        else
            hyprctl eval "hl.config({ decoration = { blur = { enabled = true } } })" >/dev/null 2>&1
            notify-send "Blur" "on" 2>/dev/null &
        fi
        exit 0
        ;;
    "100%") opacity=1.0 ;;
    "90%")  opacity=0.9 ;;
    "85%")  opacity=0.85 ;;
    "80%")  opacity=0.8 ;;
    "70%")  opacity=0.7 ;;
    "60%")  opacity=0.6 ;;
    "50%")  opacity=0.5 ;;
    "40%")  opacity=0.4 ;;
    *) exit 0 ;;
esac

sed -i "s/^local window_opacity = .*/local window_opacity = $opacity/" ~/.config/hypr/rules.lua

hyprctl reload
