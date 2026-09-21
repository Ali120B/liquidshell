#!/usr/bin/env bash
# Waybar custom/vpn module: small status pill next to RAM.
# Shown only when the flag file exists (install.sh prompt creates it).
# JSON output: {"text","class","tooltip"} with return-type=json.
set -uo pipefail

FLAG="$HOME/.config/waybar/vpn-enabled"
[[ -f "$FLAG" ]] || exit 0

if systemctl is-active --quiet cyphergated.service 2>/dev/null; then
    if ip route show default 2>/dev/null | grep -q "dev tun"; then
        echo '{"text":"VPN ●","class":"vpn-on","tooltip":"CypherGate: tunnel up (click to open)"}'
    else
        echo '{"text":"VPN ○","class":"vpn-idle","tooltip":"cyphergated up, no tunnel (click to open)"}'
    fi
else
    echo '{"text":"VPN ✕","class":"vpn-off","tooltip":"cyphergated DOWN (click to open CypherGate)"}'
fi
