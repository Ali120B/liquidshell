#!/usr/bin/env bash
# vpn-ip.sh — show current exit IP + daemon state (SUPER+ALT+V).
set -uo pipefail

IP=$(curl -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "lookup failed")
if systemctl is-active --quiet cyphergated.service 2>/dev/null; then
    if ip route show default 2>/dev/null | grep -q "dev tun"; then
        STATE="cyphergated running · tunnel up"
    else
        STATE="cyphergated running · no tunnel"
    fi
else
    STATE="cyphergated DOWN"
fi
notify-send "Exit IP: $IP" "$STATE" -a 'vpn-ip'
