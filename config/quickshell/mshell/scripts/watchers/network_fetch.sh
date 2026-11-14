#!/usr/bin/bash
active=$(nmcli -t -f active,ssid,signal dev wifi | grep '^yes:')
ssid=$(echo "$active" | cut -d: -f2)
sig=$(echo "$active" | cut -d: -f3)

bt_count=$(bluetoothctl devices Connected 2>/dev/null | wc -l)
bt=$([ "$bt_count" -gt 0 ] && echo 1 || echo 0)

vpn_nm=$(nmcli -t -f TYPE,NAME con show --active 2>/dev/null | grep -E '^(vpn|wireguard):' | head -n 1 | cut -d: -f2)
vpn_iface=$(ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^(tun|tap|wg|tailscale|warp|proton|mullvad|nordlynx|ppp|cscotun|ipsec)' | head -n 1)
vpn_active=$([ -n "$vpn_nm" ] || [ -n "$vpn_iface" ] && echo 1 || echo 0)
vpn_raw="${vpn_nm:-$vpn_iface}"

clean_vpn_name() {
    local raw="$1"
    [ -z "$raw" ] && return
    local lower=$(echo "$raw" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower" =~ proton ]]; then
        echo "Proton VPN"
    elif [[ "$lower" =~ nord ]]; then
        echo "NordVPN"
    elif [[ "$lower" =~ mullvad ]]; then
        echo "Mullvad"
    elif [[ "$lower" =~ tailscale ]]; then
        echo "Tailscale"
    elif [[ "$lower" =~ surfshark ]]; then
        echo "Surfshark"
    elif [[ "$lower" =~ warp ]]; then
        echo "Cloudflare WARP"
    elif [[ "$lower" =~ express ]]; then
        echo "ExpressVPN"
    elif [[ "$lower" =~ windscribe ]]; then
        echo "Windscribe"
    elif [[ "$lower" =~ ^wg[0-9]*$ || "$lower" =~ ^wireguard ]]; then
        echo "WireGuard"
    elif [[ "$lower" =~ ^tun[0-9]*$ || "$lower" =~ ^tap[0-9]*$ || "$lower" =~ openvpn ]]; then
        echo "OpenVPN"
    else
        echo "$raw" | sed -E 's/[ -]+[A-Z0-9_-]*#[0-9]+//g; s/[ -]+(FREE|[A-Z]{2}-?[0-9]+)//g' | sed -E 's/ +$//'
    fi
}

vpn_name=$(clean_vpn_name "$vpn_raw")
vpn_name="${vpn_name//:::/_}"

echo "${ssid:-disconnected}:::${sig:-0}:::${bt}:::${vpn_active}:::${vpn_name}"
