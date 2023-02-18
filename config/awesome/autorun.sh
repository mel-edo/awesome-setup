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
#run "discord"
run "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
run "batsignal"

killall -q polybar
polybar left &
polybar right &
polybar middle &
