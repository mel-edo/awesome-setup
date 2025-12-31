#!/bin/sh

WORKSPACE=$(hyprctl activeworkspace | grep ID -m 1 | awk '{print $3}')

if [[ $WORKSPACE < 5 ]]; then
  echo $WORKSPACE
  hyprctl dispatch workspace +1
fi

