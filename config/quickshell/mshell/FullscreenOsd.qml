import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "."

Scope {
    id: root

    signal forceTest(int value, string type)

    IpcHandler {
        target: "fullscreenOsd"
        function trigger(value: string, type: string) {
            SharedState.triggerOsd(Number(value), type)
        }
        function testForce(value: string, type: string) {
            root.forceTest(Number(value), type)
        }
        function testShare(active: string) {
            SharedState.isScreenSharing = (active === "true" || active === "1")
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            WlrLayershell {
                id: osdWindow
                required property var modelData
                screen: modelData

                anchors.top: true
                anchors.left: true
                anchors.right: true
                implicitHeight: 120
                color: "transparent"
                layer: WlrLayer.Overlay
                exclusiveZone: -1
                keyboardFocus: WlrKeyboardFocus.None
                mask: Region {} // Completely click-through for zero gaming interference

                property var hlMonitor: Hyprland.monitorFor(modelData)
                property var activeWs: hlMonitor ? hlMonitor.activeWorkspace : Hyprland.focusedWorkspace

                property bool isTargetScreen: (Quickshell.screens.length <= 1) ||
                                              (!Hyprland.focusedWorkspace?.monitor) ||
                                              (Hyprland.focusedWorkspace.monitor.name === modelData.name)

                property bool isFullscreen: isTargetScreen && (
                    (Hyprland.focusedWorkspace?.hasFullscreen ?? false) ||
                    (activeWs?.hasFullscreen ?? false) ||
                    ((Hyprland.activeToplevel?.lastIpcObject?.fullscreen ?? 0) > 0)
                )

                property int osdValue: 50
                property string osdType: "volume"
                property bool isOsdIdle: false
                property bool isShowing: false
                property bool isDotVisible: isFullscreen && SharedState.isScreenSharing

                visible: isShowing || openAnim.running || closeAnim.running || isDotVisible || (shareDot && shareDot.opacity > 0)

                function displayOsd(value, type) {
                    osdValue = value
                    osdType = type
                    isOsdIdle = false

                    if (closeAnim.running) closeAnim.stop()
                    isShowing = true
                    openAnim.restart()

                    idleTimer.restart()
                    hideTimer.restart()
                }

                function closeImmediately() {
                    hideTimer.stop()
                    idleTimer.stop()
                    openAnim.stop()
                    closeAnim.stop()
                    osdWindow.isShowing = false
                    osdCard.opacity = 0.0
                    osdCard.y = -60
                    osdCard.scale = 0.85
                }

                onIsFullscreenChanged: {
                    if (!isFullscreen && isShowing) {
                        closeImmediately()
                    } else if (isFullscreen && SharedState.isOsdActive && !isShowing) {
                        displayOsd(SharedState.currentOsdValue, SharedState.currentOsdType)
                    }
                }

                Connections {
                    target: root
                    function onForceTest(value, type) {
                        osdWindow.displayOsd(value, type)
                    }
                }

                Connections {
                    target: SharedState
                    function onOsdRequested(value, type) {
                        if (!osdWindow.isFullscreen) return
                        osdWindow.displayOsd(value, type)
                    }
                }

                Timer {
                    id: idleTimer
                    interval: 800
                    onTriggered: osdWindow.isOsdIdle = true
                }

                Timer {
                    id: hideTimer
                    interval: 2200
                    onTriggered: {
                        openAnim.stop()
                        closeAnim.restart()
                    }
                }

                ParallelAnimation {
                    id: openAnim
                    NumberAnimation {
                        target: osdCard
                        property: "y"
                        to: 24
                        duration: 250
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                    NumberAnimation {
                        target: osdCard
                        property: "opacity"
                        to: 1.0
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: osdCard
                        property: "scale"
                        to: 1.0
                        duration: 220
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }

                ParallelAnimation {
                    id: closeAnim
                    NumberAnimation {
                        target: osdCard
                        property: "y"
                        to: -60
                        duration: 200
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: osdCard
                        property: "opacity"
                        to: 0.0
                        duration: 180
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: osdCard
                        property: "scale"
                        to: 0.85
                        duration: 200
                        easing.type: Easing.InQuad
                    }
                    onFinished: {
                        osdWindow.isShowing = false
                    }
                }

                Rectangle {
                    id: osdCard
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -60
                    opacity: 0.0
                    scale: 0.85
                    width: 252
                    height: 52
                    radius: height / 2
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2)

                    Item {
                        id: osdLayout
                        anchors.centerIn: parent
                        width: 220
                        height: 36

                        // Base track
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Theme.highlight
                        }

                        // Progress fill
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: sliderHead.x + sliderHead.width
                            radius: height / 2
                            color: osdWindow.osdValue > 100 ? Theme.danger : Theme.accent
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Knob indicator
                        Rectangle {
                            id: sliderHead
                            width: parent.height
                            height: parent.height
                            radius: width / 2
                            color: Theme.text
                            x: (Math.max(0, Math.min(osdWindow.osdValue, 100)) / 100) * (parent.width - width)

                            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (osdWindow.osdType === "volume") {
                                        if (osdWindow.osdValue <= 0) return "󰖁"
                                        if (osdWindow.osdValue < 33) return "󰕿"
                                        if (osdWindow.osdValue < 66) return "󰖀"
                                        return "󰕾"
                                    } else {
                                        if (osdWindow.osdValue < 33) return "󰃞"
                                        if (osdWindow.osdValue < 66) return "󰃟"
                                        return "󰃠"
                                    }
                                }
                                color: Theme.background
                                font.pixelSize: osdWindow.osdType === "volume" ? 18 : 16
                                opacity: osdWindow.isOsdIdle ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: osdWindow.osdValue
                                color: Theme.background
                                font.pixelSize: 13
                                font.bold: true
                                opacity: osdWindow.isOsdIdle ? 0 : 1
                                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                            }
                        }
                    }
                }

                // Screen sharing / recording indicator dot in top-right
                Rectangle {
                    id: shareDot
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 3
                    anchors.rightMargin: 3
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.accent

                    opacity: osdWindow.isDotVisible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }
        }
    }
}
