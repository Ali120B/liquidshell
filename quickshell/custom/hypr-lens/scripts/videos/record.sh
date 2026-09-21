#!/usr/bin/env bash
# hypr-lens record backend. Expected CLI (see SnipCommands.qml:163):
#   record.sh --region 'X,Y WxH' [--sound]  -> start wf-recorder on that region
#   record.sh                               -> stop current recording (toggle)
set -euo pipefail

OUT_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/hypr-lens"
mkdir -p "$OUT_DIR"

# No args = stop toggle (RegionSelection.qml:248 calls it bare when wf-recorder is already running)
if [[ $# -eq 0 ]]; then
    if pgrep -x wf-recorder >/dev/null; then
        pkill -SIGINT -x wf-recorder
        notify-send 'Recording stopped' "Saved to $OUT_DIR" -a 'hypr-lens' & disown
    else
        notify-send 'No recording' 'wf-recorder is not running' -a 'hypr-lens' & disown
    fi
    exit 0
fi

REGION=""
SOUND=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --region) REGION="${2:-}"; shift 2 ;;
        --sound) SOUND=1; shift ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$REGION" ]]; then
    echo "--region is required" >&2
    exit 1
fi

# Already recording? Stop instead of stacking instances.
if pgrep -x wf-recorder >/dev/null; then
    pkill -SIGINT -x wf-recorder
    notify-send 'Recording stopped' "Saved to $OUT_DIR" -a 'hypr-lens' & disown
    exit 0
fi

FILE="$OUT_DIR/recording_$(date +'%Y-%m-%d_%H.%M.%S').mp4"
if [[ $SOUND -eq 1 ]]; then
    nohup wf-recorder -g "$REGION" -a -f "$FILE" >/dev/null 2>&1 &
else
    nohup wf-recorder -g "$REGION" -f "$FILE" >/dev/null 2>&1 &
fi
disown
sleep 0.5
if pgrep -x wf-recorder >/dev/null; then
    notify-send 'Recording started' "$FILE" -a 'hypr-lens' & disown
else
    notify-send 'Recording failed' 'wf-recorder exited immediately' -a 'hypr-lens' -u critical & disown
    exit 1
fi
