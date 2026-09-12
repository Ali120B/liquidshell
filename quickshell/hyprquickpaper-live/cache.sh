#!/usr/bin/env bash
# Thumbnail generator for live wallpapers (video + gif + image).
# Video -> ffmpeg first frame, images/gif -> ImageMagick first frame.
# Output is always "$cache_path/<filename>.jpg" so QML just appends .jpg.

CONFIG="$1/config.json"

wallpaper_path=$(jq -r '.wallpaper_path' "$CONFIG")
cache_path=$(jq -r '.cache_path' "$CONFIG")
cache_batch_size=$(jq -r '.cache_batch_size' "$CONFIG")

mkdir -p "$cache_path"

echo "Live wallpaper path: $wallpaper_path"
echo "Cache path: $cache_path"

find "$wallpaper_path" -type f \( \
    -iname "*.mp4" -o \
    -iname "*.webm" -o \
    -iname "*.mkv" -o \
    -iname "*.mov" -o \
    -iname "*.gif" -o \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.png" \
\) | while read -r img; do

    filename=$(basename "$img")
    out="$cache_path/$filename.jpg"

    if [[ -f "$out" ]]; then
        continue
    fi

    echo "Generating thumbnail for $filename"

    case "$img" in
        *.mp4|*.MP4|*.webm|*.WEBM|*.mkv|*.MKV|*.mov|*.MOV)
            ffmpeg -y -loglevel error -i "$img" -vframes 1 -vf "scale=-1:500" "$out" &
            ;;
        *)
            convert "$img[0]" -thumbnail x500 -strip -quality 85 "$out" &
            ;;
    esac

    # Only limit jobs if batch_size > 0
    if (( cache_batch_size > 0 )); then
        while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
            wait -n
        done
    fi

done

wait

echo "Live thumbnail generation complete."
