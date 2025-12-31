pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick.Controls

import "../Data/" as Dat

Item {
    width: 320
    height: 110

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // Placeholder properties for brightness and Bluetooth battery:
    property real brightnessValue: 0
    property real bluetoothBatteryValue: 0

    Timer {
        id: brightnessTimer
        interval: 210
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            var xhr1 = new XMLHttpRequest();
            xhr1.open("GET", "file:///tmp/brightness_value");
            xhr1.onreadystatechange = function() {
                if (xhr1.readyState === XMLHttpRequest.DONE) {
                    const val1 = xhr1.responseText.trim();
                    const newValue = parseInt(val1);
                    const valid = !isNaN(newValue) && newValue >= 0 && newValue <= 100;

                    if (valid) { brightnessValue = newValue; }
                }
            }
            xhr1.send();
        }
    }

    Timer {
        id: batteryTimer
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "file:///tmp/bluetooth_battery");
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    const val = xhr.responseText.trim();
                    bluetoothBatteryValue = val === "n/a" ? 0 : parseInt(val);
                }
            }
            xhr.send();
        }
    }

    Rectangle {
        id: container
        anchors.fill: parent
        radius: 20
        color: Dat.Colors.surface_container_low

        Column {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 20

            // Top row with 3 percentage displays
            Row {
                width: parent.width
                height: 24
                spacing: 40
                anchors.horizontalCenter: parent.horizontalCenter

                // Volume %
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    IconImage {
                        source: Quickshell.iconPath("audio-volume-medium-symbolic")
                        implicitWidth: 16
                        implicitHeight: 16
                    }
                    Text {
                        text: `${Math.round((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100)}%`
                        font.pixelSize: 14
                        color: Dat.Colors.on_surface
                        width: 40
                    }
                }

                // Brightness %
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    IconImage {
                        source: Qt.resolvedUrl("../svg/brightness-symbolic")
                        implicitWidth: 18
                        implicitHeight: 18
                    }
                    Text {
                        text: brightnessValue + "%"
                        font.pixelSize: 14
                        color: Dat.Colors.on_surface
                        width: 40
                    }
                }

                // Bluetooth Battery %
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    IconImage {
                        source: Quickshell.iconPath("bluetooth-battery-symbolic")
                        implicitWidth: 15
                        implicitHeight: 15
                    }
                    Text {
                        text: bluetoothBatteryValue == 0 ? "n/a" : bluetoothBatteryValue + "%"
                        font.pixelSize: 14
                        color: Dat.Colors.on_surface
                        width: 40
                    }
                }
            }

            Row {
                id: volumeRow
                width: parent.width
                spacing: 10
                height: 24

                IconImage {
                    source: { 
                        const vol = Pipewire.defaultAudioSink.audio.volume;
                        if (vol == 0) {
                            return Quickshell.iconPath("audio-volume-muted-symbolic");
                        } else if (vol <= 0.33) {
                            return Quickshell.iconPath("audio-volume-low-symbolic");
                        } else if (vol <= 0.66) {
                            return Quickshell.iconPath("audio-volume-medium-symbolic");
                        } else {
                            return Quickshell.iconPath("audio-volume-high-symbolic");
                        }
                    }
                    implicitWidth: 20
                    implicitHeight: 20
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: sliderContainer
                    width: parent.width - 40
                    height: 24

                    Rectangle {
                        id: sliderBackground
                        anchors.fill: parent
                        radius: height / 2
                        color: Dat.Colors.surface_container
                        clip: true

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            drag.target: null

                            onPressed: (mouse) => {
                                const relativeX = mouse.x;
                                const newVolume = Math.max(0, Math.min(2, relativeX / sliderBackground.width));
                                Pipewire.defaultAudioSink.audio.volume = newVolume;
                            }

                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    const relativeX = mouse.x;
                                    const newVolume = Math.max(0, Math.min(2, relativeX / sliderBackground.width));
                                    Pipewire.defaultAudioSink.audio.volume = newVolume;
                                }
                            }
                        }

                        Rectangle {
                            id: progressBar
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            radius: height / 2
                            width: sliderBackground.width * Math.min(1, Pipewire.defaultAudioSink?.audio.volume ?? 0)
                            color: (Pipewire.defaultAudioSink?.audio.volume ?? 0) > 1.01 ? Dat.Colors.error : Dat.Colors.primary

                            height: {
                                const vol = Pipewire.defaultAudioSink?.audio.volume ?? 0;
                                if (vol <= 0.05) {
                                    return 10;
                                } else if (vol <= 0.10) {
                                    return 20;
                                } else {
                                    return sliderBackground.height;
                                }
                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.InOutQuad
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }
            Row {
                id: brightnessRow
                width: parent.width
                spacing: 10
                height: 24

                IconImage {
                    source: { 
                        if (brightnessValue <= 33) {
                            return Qt.resolvedUrl("../svg/brightness-low-symbolic");
                        } else if (brightnessValue <= 66) {
                            return Qt.resolvedUrl("../svg/brightness-symbolic");
                        } else {
                            return Qt.resolvedUrl("../svg/brightness-high-symbolic");
                        }
                    }
                    implicitWidth: 20
                    implicitHeight: 20
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: sliderContainer_b
                    width: parent.width - 40
                    height: 24

                    Rectangle {
                        id: sliderBackground_b
                        anchors.fill: parent
                        radius: height / 2
                        color: Dat.Colors.surface_container
                        clip: true

                        Rectangle {
                            id: progressBar_b
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            radius: height / 2
                            width: sliderBackground_b.width * Math.min(1, (brightnessValue ?? 0) / 100)
                            color: Dat.Colors.primary

                            height: {
                                if (brightnessValue <= 5) {
                                    return 10;
                                } else if (brightnessValue <= 10) {
                                    return 20;
                                } else {
                                    return sliderBackground_b.height;
                                }
                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.InOutQuad
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}