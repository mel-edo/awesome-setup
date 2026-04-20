#!/usr/bin/env bash
ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
bt=$(bluetoothctl info 2>/dev/null | grep -c "Connected: yes")
echo "${ssid:-disconnected} $bt"