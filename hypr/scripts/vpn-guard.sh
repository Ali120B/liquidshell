#!/usr/bin/env bash
# vpn-guard.sh — keep an eye on cyphergated.
# Every 30s: if the daemon dropped, notify (critical) and try to restart;
# on recovery, notify with the new exit IP.
# Started from hyprland.start. Restart uses pkexec so auth is graphical.
set -uo pipefail

DOWN=0
while true; do
    if systemctl is-active --quiet cyphergated.service 2>/dev/null; then
        if [[ $DOWN -eq 1 ]]; then
            IP=$(curl -s --max-time 8 https://api.ipify.org 2>/dev/null || echo unknown)
            notify-send 'VPN back up' "cyphergated running · exit IP $IP" -a 'vpn-guard' & disown
            DOWN=0
        fi
    else
        if [[ $DOWN -eq 0 ]]; then
            notify-send 'VPN down' 'cyphergated stopped — attempting restart' -a 'vpn-guard' -u critical & disown
            pkexec systemctl start cyphergated.service 2>/dev/null \
                || sudo -n systemctl start cyphergated.service 2>/dev/null \
                || true
            DOWN=1
        fi
    fi
    sleep 30
done
