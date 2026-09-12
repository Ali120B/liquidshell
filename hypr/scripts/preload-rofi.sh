#!/bin/bash
# Pre-warm rofi's page cache so it launches instantly even after idle
# Reads rofi binary + dependencies into RAM without showing any window

ROFI_BIN="$(which rofi 2>/dev/null)"
[ -z "$ROFI_BIN" ] && exit 0

cat "$ROFI_BIN" > /dev/null 2>&1

ldd "$ROFI_BIN" 2>/dev/null | awk '/=>/ {print $3}' | while read -r lib; do
    [ -f "$lib" ] && cat "$lib" > /dev/null 2>&1
done

fc-match "Iosevka" > /dev/null 2>&1
fc-match "Iosevka Nerd Font" > /dev/null 2>&1
