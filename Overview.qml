import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "."

Scope {
    id: root

    property bool isOpen: false

    IpcHandler {
        target: "overview"
        function toggleOverview(): void {
            shellRoot.overviewOpen = !shellRoot.overviewOpen
        }
    }

    ListModel {
        id: windowModel
    }

    Process {
        id: hyprctlFocus
        property string targetAddr: ""
        command: ["sh", "-c", "sleep 0.1 && hyprctl dispatch focuswindow address:" + targetAddr]
    }

    function populateWindows() {
        windowModel.clear()
        let windows = Hyprland.toplevels.values
        
        for (let i = 0; i < windows.length; i++) {
            let w = windows[i]
            
            if (!w.lastIpcObject) continue;

            let winClass = w.lastIpcObject.class || ""
            
            if (winClass !== "" && w.title !== "") {
                
                let wsName = w.workspace ? w.workspace.name : "?"
                if (wsName.startsWith("special")) wsName = "s"

                let iconName = winClass
                let lowerClass = winClass.toLowerCase()
                if (lowerClass === "codium") iconName = "vscodium"
                else if (lowerClass === "zen") iconName = "zen-browser"
                else if (lowerClass === "xreader") iconName = "document-viewer"

                let rawAddress = String(w.address).trim()
                if (!rawAddress.startsWith("0x")) rawAddress = "0x" + rawAddress

                windowModel.append({
                    winAddress: rawAddress, 
                    winTitle: w.title,
                    winIconName: iconName,
                    winWorkspace: wsName
                })
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            WlrLayershell {
                id: overviewRoot
                required property var modelData
                screen: modelData

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true
                layer: WlrLayer.Overlay
                
                keyboardFocus: WlrKeyboardFocus.OnDemand 
                color: "transparent"
                
                property bool isActuallyVisible: false
                visible: isActuallyVisible

                Timer {
                    id: openDelayTimer
                    interval: 30
                    onTriggered: {
                        root.populateWindows()
                        openAnim.restart()
                    }
                }

                Connections {
                    target: root
                    function onIsOpenChanged() {
                        if (root.isOpen) {
                            closeAnim.stop()
                            overviewRoot.isActuallyVisible = true
                            openDelayTimer.restart()
                        } else {
                            openDelayTimer.stop()
                            openAnim.stop()
                            closeAnim.restart()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: shellRoot.overviewOpen = false
                }

                Rectangle {
                    id: droplet
                    
                    x: (parent.width - width) / 2
                    y: -100
                    width: 40; height: 40; radius: 20
                    
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2)
                    clip: true

                    Item {
                        id: listContent
                        width: 600
                        height: Math.max(60, Math.min((windowModel.count * 56) + 24, modelData.height * 0.8))
                        
                        anchors.top: parent.top 
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0

                        ListView {
                            id: windowList
                            anchors.fill: parent
                            anchors.margins: 12 
                            model: windowModel
                            clip: true
                            
                            highlightMoveDuration: 150 

                            onVisibleChanged: {
                                if (visible) {
                                    forceActiveFocus()
                                    currentIndex = 0
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Up) {
                                    windowList.decrementCurrentIndex()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Down) {
                                    windowList.incrementCurrentIndex()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (windowList.currentIndex >= 0 && windowList.currentIndex < windowModel.count) {
                                        let addr = windowModel.get(windowList.currentIndex).winAddress
                                        shellRoot.overviewOpen = false
                                        hyprctlFocus.targetAddr = addr
                                        hyprctlFocus.running = true
                                    }
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    shellRoot.overviewOpen = false
                                    event.accepted = true
                                }
                            }

                            delegate: Rectangle {
                                width: windowList.width
                                height: 56
                                radius: 8
                                
                                property bool isActive: windowList.currentIndex === index || hoverArea.hovered
                                color: isActive ? Theme.surfaceHover : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Image {
                                    id: winIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "image://icon/" + model.winIconName 
                                    width: 28; height: 28
                                    sourceSize: Qt.size(28, 28)
                                    onStatusChanged: {
                                        if (status === Image.Error) source = "" 
                                    }
                                }

                                Text {
                                    anchors.left: winIcon.right
                                    anchors.leftMargin: 16
                                    anchors.right: wsBadge.left
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    text: model.winTitle
                                    color: Theme.text
                                    font.pixelSize: 15
                                    font.bold: parent.isActive 
                                    elide: Text.ElideRight 
                                }

                                Rectangle {
                                    id: wsBadge
                                    anchors.right: parent.right
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.05)
                                    border.width: 1
                                    border.color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.15)
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: model.winWorkspace 
                                        color: Theme.subtext
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                HoverHandler { id: hoverArea; cursorShape: Qt.PointingHandCursor }
                                
                                TapHandler {
                                    onTapped: {
                                        windowList.currentIndex = index
                                        let addr = windowModel.get(windowList.currentIndex).winAddress
                                        shellRoot.overviewOpen = false
                                        hyprctlFocus.targetAddr = addr
                                        hyprctlFocus.running = true
                                    }
                                }
                            }
                        }
                    }
                }

                SequentialAnimation {
                    id: openAnim
                    
                    NumberAnimation { 
                        target: droplet; 
                        property: "y"; 
                        to: (modelData.height * 0.20) - 30; 
                        duration: 300; 
                        easing.type: Easing.OutExpo 
                    }
                    
                    ParallelAnimation {
                        NumberAnimation { target: droplet; property: "width"; to: 600; duration: 300; easing.type: Easing.OutExpo }
                        NumberAnimation { target: droplet; property: "height"; to: windowModel.count > 0 ? Math.min((windowModel.count * 56) + 24, modelData.height * 0.8) : 80; duration: 300; easing.type: Easing.OutExpo } 
                        NumberAnimation { target: droplet; property: "radius"; to: 16; duration: 300; easing.type: Easing.OutExpo }
                        NumberAnimation { target: listContent; property: "opacity"; to: 1; duration: 250 }
                    }
                    
                    ScriptAction { script: windowList.forceActiveFocus() }
                }

                SequentialAnimation {
                    id: closeAnim
                    
                    ParallelAnimation {
                        NumberAnimation { target: listContent; property: "opacity"; to: 0; duration: 150 }
                        NumberAnimation { target: droplet; property: "width"; to: 40; duration: 250; easing.type: Easing.OutExpo }
                        NumberAnimation { target: droplet; property: "height"; to: 40; duration: 250; easing.type: Easing.OutExpo }
                        NumberAnimation { target: droplet; property: "radius"; to: 20; duration: 250; easing.type: Easing.OutExpo }
                    }
                    
                    NumberAnimation { target: droplet; property: "y"; to: -100; duration: 250; easing.type: Easing.InBack }
                    
                    onFinished: {
                        if (!root.isOpen) {
                            overviewRoot.isActuallyVisible = false
                        }
                    }
                }
            }
        }
    }
}