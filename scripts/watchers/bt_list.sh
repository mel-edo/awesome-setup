#!/usr/bin/bash
# Output: MAC|NAME|CONNECTED(0/1)|BATTERY|PAIRED(0/1)
connected_macs=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')
paired_macs=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}')

bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
    is_connected=0
    is_paired=0
    bat="--"

    if echo "$paired_macs" | grep -q "$mac"; then
        is_paired=1
    fi
    if [ "$is_paired" -eq 0 ] && [[ "$name" == "$mac"* || -z "$name" || "$name" =~ ^([0-9A-F]{2}-){5}[0-9A-F]{2}$ ]]; then
        continue
    fi
    if echo "$connected_macs" | grep -q "$mac"; then
        is_connected=1
        bat=$(bluetoothctl info "$mac" 2>/dev/null | grep 'Battery Percentage:' | awk -F '[()]' '{print $2}')
        [ -z "$bat" ] && bat="--"
    fi
    echo "$mac|$name|$is_connected|$bat|$is_paired"
done