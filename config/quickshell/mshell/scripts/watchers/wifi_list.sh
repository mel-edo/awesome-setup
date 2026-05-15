#!/usr/bin/bash
# Output: SSID:SIGNAL:SECURITY
nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list --rescan no 2>/dev/null | \
  grep -v '^:' | sort -t: -k2 -rn | awk -F: '!seen[$1]++' | head -15
