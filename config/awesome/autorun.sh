#!/bin/sh

run() {
  if ! pgrep -f "$1" ;
  then
    "$@"&
  fi
}

run "picom"
run "unclutter"
run "firefox"
run "copyq"
run "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
run "nm-applet"
run "batsignal"
run "redshift"
run "sunshine"

killall -q polybar
polybar left &
polybar right &
polybar middle &
polybar tray &
polybar xwindow &

pkill xidlehook
xidlehook --detect-sleep --not-when-audio --timer 300 'cool-retro-term --fullscreen -e sh ~/cmatrix.sh' '' --timer 600 'pkill cool-retro-term && systemctl suspend' ''

