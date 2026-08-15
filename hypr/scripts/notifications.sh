#!/bin/bash
# Notification history menu using rofi

NOTIFS=$(dunstctl history 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    notifs = data.get('data', [])
    for n in notifs:
        summary = n.get('summary', {}).get('data', 'No summary')
        body = n.get('body', {}).get('data', '')
        appname = n.get('appname', {}).get('data', '')
        if body:
            print(f'{appname}: {summary} — {body}')
        else:
            print(f'{appname}: {summary}')
except:
    pass
" 2>/dev/null)

if [ -z "$NOTIFS" ]; then
    notify-send "Notifications" "No notifications in history"
    exit 0
fi

echo "$NOTIFS" | rofi -dmenu \
    -p "  Notifications" \
    -theme-str 'window { location: center; width: 450px; }' \
    -theme-str 'listview { lines: 8; }' \
    -theme-str '* { background-color: #1a1b26E6; text-color: #c0caf5; }' \
    -theme-str 'inputbar { background-color: #24283a; border-radius: 10px; padding: 8px 14px; }' \
    -theme-str 'entry { background-color: transparent; text-color: #c0caf5; }' \
    -theme-str 'prompt { background-color: transparent; text-color: #7aa2f7; }' \
    -theme-str 'element { padding: 8px 14px; border-radius: 8px; }' \
    -theme-str 'element selected { background-color: #3b4261; text-color: #c0caf5; }' \
    -theme-str 'element normal { background-color: transparent; }'
