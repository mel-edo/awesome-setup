#!/bin/sh

hyprshot -m region -s -f "ocrshot.png"
TEXT=$(tesseract ~/Pictures/ocrshot.png stdout)
echo "$TEXT" | wl-copy
notify-send "OCR" "Text copied to clipboard"
