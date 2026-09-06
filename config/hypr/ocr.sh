#!/bin/sh
# Trigger Quickshell interactive frozen region OCR
qs -p "$HOME/.config/quickshell/mshell/main.qml" ipc call screenshot ocr
