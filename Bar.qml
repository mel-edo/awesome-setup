import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "."

// Wrap everything in a single root Scope
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

    // 2. The Floating Workspace Pill
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
                implicitWidth: pill.width
                implicitHeight: pill.height

                Rectangle {
                    id: pill
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
                anchors.right: true
                exclusiveZone: -1
                color: "transparent"
                implicitWidth: modelData.width
                implicitHeight: 30

                Rectangle {
                    id: titlePill
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.surface
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: 12
                    bottomRightRadius: 12
                    height: 30
                    width: Math.min(titleText.implicitWidth + 24, 400)

                    Text {
                        id: titleText
                        anchors.centerIn: parent
                        text: {
                            Hyprland.focusedWorkspace
                            let ws = Hyprland.focusedWorkspace
                            if (ws && ws.toplevels.values.length === 0) return "~/"
                            return Hyprland.activeToplevel?.title ?? "~/"
                        }
                        color: Theme.text
                        font.pixelSize: 12
                        width: parent.width - 24
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

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
                            batLevel = parseInt(parts[0])
                            batStatus = parts[1]
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
                            statusPanel.btConnected = parts[1] === "1"
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

                    // battery pill
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
                                    if (batStatus === "Charging") return "󰂄"
                                    if (batLevel < 10) return "󰁺"
                                    if (batLevel < 30) return "󰁼"
                                    if (batLevel < 60) return "󰁿"
                                    if (batLevel < 90) return "󰂁"
                                    return "󰁹"
                                }
                                color: {
                                    if (batStatus === "Charging") return Theme.accent
                                    if (batLevel < 20) return Theme.danger
                                    return Theme.accent
                                }
                                font.pixelSize: 14
                            }
                            Text {
                                id: batText
                                text: "?%"
                                color: Theme.text
                                font.pixelSize: 12
                            }
                        }
                    }

                    // network pill
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
                                text: netSsid !== "" ? "󰤨" : "󰤭"
                                color: netSsid !== "" ? Theme.accent : Theme.danger
                                font.pixelSize: 14
                            }
                            Text {
                                text: {
                                        text: btConnected ? "󰂯" : "󰂲"
                                        color: btConnected ? Theme.accent : Theme.subtext
                                        font.pixelSize: 14
                                }
                                color: btConnected ? Theme.accent : Theme.subtext
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }
        }
    }
}