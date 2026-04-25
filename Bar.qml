import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "."

Scope {

    // 1. The Invisible Strut
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                required property var modelData
                screen: modelData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                implicitHeight: 38
                exclusiveZone: 28
                color: "transparent"
                mask: Region {}
            }
        }
    }

    // 2. Left side — workspace dots + title
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                required property var modelData
                screen: modelData
                anchors.top: true
                anchors.left: true
                margins.top: 0
                margins.left: 8
                exclusiveZone: -1
                color: "transparent"
                implicitWidth: wsPill.width
                implicitHeight: 30

                Rectangle {
                    id: wsPill
                    color: Theme.surface
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: 12
                    bottomRightRadius: 12
                    height: 30
                    width: wsRow.width + 24

                    Row {
                        id: wsRow
                        anchors.centerIn: parent
                        spacing: 10

                        Repeater {
                            model: 8

                            Rectangle {
                                id: dot
                                width: 14
                                height: 14
                                radius: 7
                            
                                property int workspaceId: index + 1
                                property bool isActive: Hyprland.focusedWorkspace?.id === workspaceId
                                property bool isOccupied: {
                                    Hyprland.focusedWorkspace
                                    for (let ws of Hyprland.workspaces.values) {
                                        if (ws.id === workspaceId) return true
                                    }
                                    return false
                                }

                                color: isActive ? Theme.accent : "transparent"
                                border.color: Theme.subtext
                                border.width: isActive ? 0 : 2

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.subtext
                                    visible: parent.isOccupied && !parent.isActive
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("workspace " + workspaceId)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Title pill
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                required property var modelData
                screen: modelData
                anchors.top: true
                anchors.left: true
                margins.top: 0
                margins.left: 8 + (8 * 14 + 7 * 10 + 24) + 6  // 8px screen margin + wsPill width + 6px gap
                exclusiveZone: -1
                color: "transparent"
                implicitWidth: titlePill.width
                implicitHeight: 30

                Rectangle {
                    id: titlePill
                    color: Theme.surface
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: 12
                    bottomRightRadius: 12
                    height: 30
                    width: titleText.width + 24

                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Text {
                        id: titleText
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            Hyprland.focusedWorkspace
                            let ws = Hyprland.focusedWorkspace
                            if (ws && ws.toplevels.values.length === 0) return "~/"
                            return Hyprland.activeToplevel?.title ?? "~/"
                        }
                        color: Theme.subtext
                        font.pixelSize: 14
                        width: Math.min(implicitWidth, 226)
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // 3. Right side
    Variants {
        model: Quickshell.screens
        delegate: Component {
            WlrLayershell {
                id: rightLiquidPill
                required property var modelData
                screen: modelData

                anchors.top: true
                anchors.right: true
                margins.top: 0
                margins.right: 0
                
                layer: WlrLayer.Top
                exclusiveZone: -1 
                color: "transparent"

                implicitWidth: 400
                implicitHeight: 800 

                // ─── STATE & DATA ───
                property string rightState: "idle"
                
                property string netSsid: ""
                property bool btConnected: false
                property string batStatus: "Discharging"
                property int batLevel: 100

                Process {
                    id: batteryProcess
                    command: [Quickshell.env("HOME") + "/.config/quickshell-new/mshell/scripts/watchers/battery_fetch.sh"]
                    running: true
                    stdout: SplitParser {
                        onRead: data => {
                            let parts = data.trim().split(" ")
                            rightLiquidPill.batLevel = parseInt(parts[0])
                            rightLiquidPill.batStatus = parts.slice(1).join(" ")
                        }
                    }
                }
                Timer { interval: 5000; running: true; repeat: true; onTriggered: batteryProcess.running = true }

                Process {
                    id: networkProcess
                    command: [Quickshell.env("HOME") + "/.config/quickshell-new/mshell/scripts/watchers/network_fetch.sh"]
                    running: true
                    stdout: SplitParser {
                        onRead: data => {
                            let parts = data.trim().split(" ")
                            rightLiquidPill.netSsid = parts[0] === "disconnected" ? "" : parts[0]
                            rightLiquidPill.btConnected = parts[1]?.trim() === "1"
                        }
                    }
                }
                Timer { interval: 3000; running: true; repeat: true; onTriggered: networkProcess.running = true }

                // ─── TIMERS FOR ORGANIC FEEL ───
                Timer {
                    id: openDelay
                    interval: 80
                    onTriggered: rightLiquidPill.rightState = "cc"
                }

                Timer {
                    id: closeDelay
                    interval: 300
                    onTriggered: rightLiquidPill.rightState = "idle"
                }

                // Masking the static window down to the animated background shape
                mask: Region { item: pillBackground }

                // ─── THE MORPHING BACKGROUND ───
                Rectangle {
                    id: pillBackground
                    
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 0
                    anchors.rightMargin: 8

                    color: Theme.surface
                    clip: true

                    width: rightLiquidPill.rightState === "idle" ? idleContent.implicitWidth + 24 : 340
                    height: rightLiquidPill.rightState === "idle" ? 30 : ccContent.implicitHeight + 32
                    
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                    Behavior on anchors.topMargin { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                    Behavior on anchors.rightMargin { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: rightLiquidPill.rightState === "idle" ? 12 : 16
                    bottomRightRadius: rightLiquidPill.rightState === "idle" ? 12 : 16
                    
                    Behavior on topLeftRadius { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                    Behavior on topRightRadius { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                    Behavior on bottomLeftRadius { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                    Behavior on bottomRightRadius { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

                    HoverHandler {
                        id: pillHover
                        onHoveredChanged: {
                            if (hovered) {
                                closeDelay.stop()
                                openDelay.restart()
                            } else {
                                openDelay.stop()
                                closeDelay.restart()
                            }
                        }
                    }

                    // ─── CONTENT LAYER 1: IDLE STATE ───
                    Row {
                        id: idleContent
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        anchors.rightMargin: 12
                        height: 22
                        spacing: 12

                        property bool isActive: rightLiquidPill.rightState === "idle"
                        visible: isActive
                        opacity: isActive ? 1 : 0
                        Behavior on opacity { 
                            SequentialAnimation {
                                PauseAnimation { duration: idleContent.isActive ? 250 : 0 }
                                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                            }
                        }

                        Row {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: rightLiquidPill.netSsid !== "" ? "󰤨" : "󰤭"; color: rightLiquidPill.netSsid !== "" ? Theme.accent : Theme.danger; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Rectangle { width: 2; height: 14; radius: 1; color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2); anchors.verticalCenter: parent.verticalCenter }

                        Row {
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: {
                                    if (rightLiquidPill.batStatus === "Charging") return "󰂄"
                                    if (rightLiquidPill.batLevel < 10) return "󰁺"
                                    if (rightLiquidPill.batLevel < 30) return "󰁼"
                                    if (rightLiquidPill.batLevel < 60) return "󰁿"
                                    if (rightLiquidPill.batLevel < 90) return "󰂁"
                                    return "󰁹"
                                }
                                color: rightLiquidPill.batStatus === "Charging" ? Theme.accent : (rightLiquidPill.batLevel < 20 ? Theme.danger : Theme.accent)
                                font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter
                            }
                            Text { text: rightLiquidPill.batLevel + "%"; color: Theme.text; font.pixelSize: 14; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    // ─── CONTENT LAYER 2: EXPANDED CONTROL CENTER ───
                    ControlCenter {
                        id: ccContent
                        layer.enabled: true 
                        
                        width: 308 
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.top: parent.top
                        anchors.topMargin: 16

                        isOpen: rightLiquidPill.rightState === "cc"
                        parentWindow: rightLiquidPill
                        netSsid: rightLiquidPill.netSsid
                        batLevel: rightLiquidPill.batLevel
                        batStatus: rightLiquidPill.batStatus
                        btConnected: rightLiquidPill.btConnected

                        property bool isActive: rightLiquidPill.rightState === "cc"
                        visible: isActive
                        opacity: isActive ? 1 : 0
                        
                        Behavior on opacity {
                            SequentialAnimation {
                                PauseAnimation { duration: ccContent.isActive ? 100 : 0 }
                                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }
            }
        }
    }
}