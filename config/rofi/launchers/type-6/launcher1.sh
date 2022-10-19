#!/usr/bin/env bash
dir="$HOME/.config/rofi/launchers/type-6"
theme='style-10'

## Run
rofi \
    -show window \
    -theme ${dir}/${theme}.rasi
