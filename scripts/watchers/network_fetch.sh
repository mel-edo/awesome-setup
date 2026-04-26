#!/usr/bin/bash
active=$(nmcli -t -f active,ssid,signal dev wifi | grep '^yes:')
ssid=$(echo "$active" | cut -d: -f2)
sig=$(echo "$active" | cut -d: -f3)

bt_count=$(bluetoothctl devices Connected 2>/dev/null | wc -l)
bt=$([ "$bt_count" -gt 0 ] && echo 1 || echo 0)

echo "${ssid:-disconnected}:::${sig:-0}:::${bt}"