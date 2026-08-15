#!/bin/bash

GPU_PERCENT=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)

if [ -z "$GPU_PERCENT" ]; then
    echo "0"
    exit 0
fi

echo "$GPU_PERCENT"