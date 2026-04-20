import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
                                    onClicked: Quickshell.exec(`hyprctl dispatch workspace ${workspaceId}`)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}