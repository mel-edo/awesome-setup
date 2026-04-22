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
                    width: Math.min(titleText.implicitWidth + 24, 250)

                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Text {
                        id: titleText
                        anchors.centerIn: parent
                        text: {
                            Hyprland.focusedWorkspace
                            let ws = Hyprland.focusedWorkspace
                            if (ws && ws.toplevels.values.length === 0) return "~/"
                            return Hyprland.activeToplevel?.title ?? "~/"
                        }
                        color: Theme.subtext
                        font.pixelSize: 14
                        width: parent.width - 24
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // 3. Right side — battery + network
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: statusPanel
                required property var modelData
                property string netSsid: ""
                property bool btConnected: false
                property string batStatus: "Discharging"
                property int batLevel: 100
                screen: modelData
                anchors.top: true
                anchors.right: true
                margins.top: 0
                margins.right: 8
                exclusiveZone: -1
                color: "transparent"
                implicitWidth: statusRow.width
                implicitHeight: 30

                Process {
                    id: batteryProcess
                    command: [Quickshell.env("HOME") + "/.config/quickshell-new/mshell/scripts/watchers/battery_fetch.sh"]
                    running: true
                    stdout: SplitParser {
                        onRead: data => {
                            let parts = data.trim().split(" ")
                            statusPanel.batLevel = parseInt(parts[0])
                            statusPanel.batStatus = parts[1]
                            batText.text = parts[0] + "%"
                        }
                    }
                }

                Timer {
                    interval: 5000
                    running: true
                    repeat: true
                    onTriggered: batteryProcess.running = true
                }

                Process {
                    id: networkProcess
                    command: [Quickshell.env("HOME") + "/.config/quickshell-new/mshell/scripts/watchers/network_fetch.sh"]
                    running: true
                    stdout: SplitParser {
                        onRead: data => {
                            let parts = data.trim().split(" ")
                            statusPanel.netSsid = parts[0] === "disconnected" ? "" : parts[0]
                            statusPanel.btConnected = parts[1]?.trim() === "1"
                        }
                    }
                }

                Timer {
                    interval: 3000
                    running: true
                    repeat: true
                    onTriggered: networkProcess.running = true
                }

                Row {
                    id: statusRow
                    spacing: 6

                    // Network pill
                    Rectangle {
                        color: Theme.surface
                        topLeftRadius: 0
                        topRightRadius: 0
                        bottomLeftRadius: 12
                        bottomRightRadius: 12
                        height: 30
                        width: netRow.width + 16

                        Row {
                            id: netRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: statusPanel.netSsid !== "" ? "󰤨" : "󰤭"
                                color: statusPanel.netSsid !== "" ? Theme.accent : Theme.danger
                                font.pixelSize: 14
                            }

                            Text {
                                text: statusPanel.btConnected ? "󰂯" : "󰂲"
                                color: statusPanel.btConnected ? Theme.accent : Theme.subtext
                                font.pixelSize: 14
                            }
                        }
                    }

                    // Battery pill
                    Rectangle {
                        color: Theme.surface
                        topLeftRadius: 0
                        topRightRadius: 0
                        bottomLeftRadius: 12
                        bottomRightRadius: 12
                        height: 30
                        width: batRow.width + 16

                        Row {
                            id: batRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: {
                                    if (statusPanel.batStatus === "Charging") return "󰂄"
                                    if (statusPanel.batLevel < 10) return "󰁺"
                                    if (statusPanel.batLevel < 30) return "󰁼"
                                    if (statusPanel.batLevel < 60) return "󰁿"
                                    if (statusPanel.batLevel < 90) return "󰂁"
                                    return "󰁹"
                                }
                                color: {
                                    if (statusPanel.batStatus === "Charging") return Theme.accent
                                    if (statusPanel.batLevel < 20) return Theme.danger
                                    return Theme.accent
                                }
                                font.pixelSize: 14
                            }

                            Text {
                                id: batText
                                text: "?%"
                                color: Theme.text
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }
        }
    }
}