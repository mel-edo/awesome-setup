import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets

Scope {
    id: root

    // Track default sink so its volume updates are observed
    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    property bool shouldShowOsd: false

    Connections {
        target: Pipewire.defaultAudioSink?.audio

        function onVolumeChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shouldShowOsd = false
    }

    LazyLoader {
        active: root.shouldShowOsd

        PanelWindow {
            anchors.top: true
            margins.top: 10
            implicitWidth: 320
            implicitHeight: 50
            color: "transparent"
            mask: Region {}
            exclusiveZone: 0

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#181825"

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    IconImage {
                        id: volumeIcon
                        source: {
                            const vol = Pipewire.defaultAudioSink?.audio.volume ?? 0;
                            if (vol === 0)
                                return Quickshell.iconPath("audio-volume-muted-symbolic");
                            else if (vol <= 0.33)
                                return Quickshell.iconPath("audio-volume-low-symbolic");
                            else if (vol <= 0.66)
                                return Quickshell.iconPath("audio-volume-medium-symbolic");
                            else
                                return Quickshell.iconPath("audio-volume-high-symbolic");
                        }
                        implicitWidth: 24
                        implicitHeight: 24
                    }

                    Rectangle {
                        id: sliderBackground
                        height: 24
                        radius: height / 2
                        color: "#6c7086"
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48

                        Rectangle {
                            id: progressBar
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            radius: parent.radius
                            width: parent.width * Math.min(1, Pipewire.defaultAudioSink?.audio.volume ?? 0)
                            color: (Pipewire.defaultAudioSink?.audio.volume ?? 0) > 1.01 ? "#f38ba8" : "#b4befe"

							height: {
								const vol = Pipewire.defaultAudioSink?.audio.volume ?? 0;
								if (vol <= 0.05) {
									return 10;
								} else if (vol <= 0.10) {
									return 20;
								} else {
									return parent.height;
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
