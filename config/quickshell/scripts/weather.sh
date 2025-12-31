#!/bin/sh

# This seems like a waste of a file but I couldn't get it to work any other way
sleep 1
# if [ 2>/dev/null 1>&2 ping -c 2 www.archlinux.org ]; then
python3 ~/.config/quickshell/scripts/weather.py
# else
#   echo "404 Net"
# fi

