#!/bin/sh

run() {
  if ! pgrep -f "$1" ;
  then
    "$@"&
  fi
}

run "picom"
run "unclutter"
run "redshift"
run "firefox"
run "copyq"
run "discocss"
run "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
run "batsignal"
run "sunshine"

killall -q polybar
polybar left &
polybar right &
polybar middle &

pkill xidlehook
xidlehook --detect-sleep --not-when-fullscreen --not-when-audio --timer 600 'betterlockscreen -l' '' --timer 1800 'systemctl suspend' ''

pkill conky
sleep 2s
conky -c ~/.config/conky/mocha.conf

