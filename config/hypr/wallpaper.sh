#!/bin/sh

WALLPAPER=$(yad --file --title="Choose a Wallpaper" --file-filter="Images | *.jpg *.jpeg *.png *.bmp *.webp" --center --filename="$HOME/Downloads/Wallpapers")

if [[ -f "$WALLPAPER" ]]; then
    swww img "$WALLPAPER" --transition-type grow --transition-fps 60 --transition-duration 3.5 --transition-pos 825,1000

    cp "$WALLPAPER" ~/.config/hypr/wallpaper.jpg
fi
