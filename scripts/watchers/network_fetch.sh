#!/usr/bin/bash
ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
bt_count=$(bluetoothctl devices Connected 2>/dev/null | wc -l)
bt=$([ "$bt_count" -gt 0 ] && echo 1 || echo 0)

echo "${ssid:-disconnected} $bt"