#!/bin/sh
# Warm terminal startup binaries + their shared libraries into the page cache
# after login, so the first fish prompt doesn't read them cold from the HDD.
for bin in fish starship fastfetch direnv zoxide hostnamectl uptime free; do
    path=$(command -v "$bin") || continue
    nice -n 19 cat "$path" >/dev/null 2>&1
    ldd "$path" 2>/dev/null | awk '/=> \// {print $3}' | while read -r lib; do
        nice -n 19 cat "$lib" >/dev/null 2>&1
    done
done
