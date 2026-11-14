#!/usr/bin/bash
action="$1"
ssid="$2"
pass="$3"

wifi_iface=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | grep ':wifi$' | head -n 1 | cut -d: -f1)
wifi_iface="${wifi_iface:-wlan0}"

case "$action" in
    connect)
        if [ -z "$ssid" ]; then
            echo "Error: SSID required" >&2
            exit 1
        fi
        # If connection profile exists in NetworkManager, try activating it first
        if nmcli -t -f NAME con show 2>/dev/null | grep -Fxq "$ssid"; then
            echo "Activating existing profile for $ssid on $wifi_iface..."
            if nmcli connection up id "$ssid" ifname "$wifi_iface" 2>&1; then
                exit 0
            fi
            echo "Profile activation failed, falling back to dev wifi connect..."
        fi
        echo "Connecting to Wi-Fi network $ssid on $wifi_iface..."
        nmcli dev wifi connect "$ssid" ifname "$wifi_iface" 2>&1
        exit $?
        ;;
    connect_pass)
        if [ -z "$ssid" ]; then
            echo "Error: SSID required" >&2
            exit 1
        fi
        echo "Connecting to Wi-Fi network $ssid with password on $wifi_iface..."
        nmcli dev wifi connect "$ssid" password "$pass" ifname "$wifi_iface" 2>&1
        exit $?
        ;;
    disconnect)
        echo "Disconnecting Wi-Fi interface $wifi_iface..."
        # If active connection exists, also deactivate profile
        active_con=$(nmcli -t -f DEVICE,CONNECTION dev 2>/dev/null | grep "^${wifi_iface}:" | cut -d: -f2)
        nmcli dev disconnect "$wifi_iface" 2>&1
        if [ -n "$active_con" ] && [ "$active_con" != "--" ]; then
            nmcli connection down id "$active_con" 2>&1
        fi
        exit 0
        ;;
    *)
        echo "Usage: $0 {connect <ssid>|connect_pass <ssid> <password>|disconnect}" >&2
        exit 1
        ;;
esac

