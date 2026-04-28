#!/usr/bin/bash
export QS_CONFIG_DIR="$HOME/.config/quickshell/mshell"
pkill -x qs 2>/dev/null
sleep 0.2
qs -p ${QS_CONFIG_DIR}/main.qml &

