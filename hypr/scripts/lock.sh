#!/usr/bin/env bash
# lock.sh — screen lock wrapper.
# Pauses video wallpapers while locked, resumes on unlock.
# hyprlock runs in the foreground and exits on unlock, so resume always runs.
# No `set -e`: resume must run even if pause (or the daemon) fails.
skwd-helm pause 2>/dev/null
hyprlock
skwd-helm resume 2>/dev/null
