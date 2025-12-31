#!/bin/sh

export QML_XHR_ALLOW_FILE_READ=1
quickshell &
quickshell -p ~/.config/quickshell/osd.qml &
quickshell -p ~/.config/quickshell/osd_b.qml &
