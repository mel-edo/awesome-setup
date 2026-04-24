#!/bin/bash
TYPE=$1
TARGET=$2
PREVIEW=$3

pkill mpvpaper 2>/dev/null
pkill -9 -f '[l]inux-wallpaperengine' 2>/dev/null

if [ "$TYPE" == "animated" ]; then
    pkill awww 2>/dev/null
    pkill awww-daemon 2>/dev/null
    nohup setsid linux-wallpaperengine -s --screen-root eDP-1 --clamp border "$TARGET" </dev/null >/dev/null 2>&1 &
    if [ -n "$PREVIEW" ] && [ -f "$PREVIEW" ]; then
        command -v matugen >/dev/null && matugen image -t scheme-tonal-spot -m dark --source-color-index 0 "$PREVIEW"
    fi
else
    if ! pgrep -x awww-daemon >/dev/null; then
        setsid awww-daemon >/dev/null 2>&1 & disown
        sleep 0.5 
    fi
    pkill -9 -f '[l]inux-wallpaperengine' 2>/dev/null
    sleep 0.15 
    awww img "$TARGET" --transition-type grow --transition-pos 0.5,0.95 --transition-duration 0.8 --transition-fps 60
    command -v matugen >/dev/null && matugen image -t scheme-tonal-spot -m dark --source-color-index 0 "$TARGET"
fi