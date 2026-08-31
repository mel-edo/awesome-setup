#!/usr/bin/env bash

QS_IPC="qs -p $HOME/.config/quickshell/mshell/main.qml ipc call record"
OUT_DIR="$HOME/Videos/screen_recorder"

if pgrep -f "[g]pu-screen-recorder -w" > /dev/null; then
    # already recording
    pkill -SIGINT -f "gpu-screen-recorder -w"
    $QS_IPC stop
    
    notify-send -u normal -t 3000 -i media-playback-stop \
        "Screen Recorder" "Recording stopped and saved to Videos."
else
    # not recording
    $QS_IPC start
    mkdir -p "$OUT_DIR"
    FILE_NAME="$(date +%Y-%m-%d_%H-%M-%S).mkv"
    
    setsid gpu-screen-recorder -w screen -k hevc -f 60 -a default_output \
        -q ultra -cr full -tune quality -ac opus \
        -o "$OUT_DIR/$FILE_NAME" &
        
    notify-send -u normal -t 3000 -i media-record \
        "Screen Recorder" "Recording started."
fi