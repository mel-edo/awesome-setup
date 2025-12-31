#!/bin/sh

WALLPAPER_DIR="$HOME/Downloads/Wallpapers"

WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | shuf -n 1)

if [ -f "$WALLPAPER" ]; then
  swww img "$WALLPAPER" --transition-type grow --transition-fps 60 --transition-duration 2 --transition-pos 790,920

  cp "$WALLPAPER" ~/.config/hypr/wallpaper.jpg
fi
