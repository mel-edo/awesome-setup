import QtQuick
import Quickshell
import Quickshell.Widgets

Scope {
    id: root

    property bool shouldShowOsd: false
    property real brightnessValue: 0
    property real prevbrightnessValue: -1

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

                    if (valid && newValue != prevbrightnessValue) {
                        brightnessValue = newValue;
                        prevbrightnessValue = newValue;
                        root.shouldShowOsd = true;
                        hideTimer1.restart()
                    }
                }
            }
            xhr1.send();
        }
    }

    Timer {
        id: hideTimer1
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
                        id: brightnessIcon
                        source: {
                            if (brightnessValue <= 33)
                                return Qt.resolvedUrl("./svg/brightness-low-symbolic");
                            else if (brightnessValue <= 66)
                                return Qt.resolvedUrl("./svg/brightness-symbolic");
                            else
                                return Qt.resolvedUrl("./svg/brightness-high-symbolic");
                        }
                        implicitWidth: 24
                        implicitHeight: 24
                    }

                    Rectangle {
                        id: sliderBackground_b
                        height: 24
                        radius: height / 2
                        color: "#6c7086"
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48

                        Rectangle {
                            id: progressBar_b
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            radius: parent.radius
                            width: parent.width * Math.min(1, (brightnessValue ?? 0) / 100)
                            color: "#b4befe"

							height: {
								if (brightnessValue <= 5) {
									return 10;
								} else if (brightnessValue <= 10) {
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
