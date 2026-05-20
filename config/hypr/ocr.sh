#!/bin/sh
IMG="/tmp/ocrshot.png"
REGION=$(slurp) || exit 1
sleep 0.1
grim -g "$REGION" "$IMG" || exit 1
TEXT=$(tesseract "$IMG" stdout 2>/dev/null)
if [ -n "$TEXT" ]; then
  echo "$TEXT" | wl-copy
  notify-send "OCR" "Text copied to clipboard"
else
  notify-send "OCR" "No text detected"
fi
