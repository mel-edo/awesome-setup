import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import "."

Scope {

    // Top strut
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

    // Left container: workspaces and title
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

    // Focused window title
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
                    width: 250 

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
                        width: Math.min(implicitWidth, parent.width - 24)
                        horizontalAlignment: Text.AlignHCenter 
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // Right container: system trays and control center
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

                implicitWidth: 800
                implicitHeight: 800 

                // Component state
                property string rightState: "idle"
                property var activeMenuHandle: null
                property string activeMenuName: ""
                property real activeMenuY: 0
                property bool isMenuOpen: activeMenuHandle !== null && rightState === "cc"
                property string netSsid: ""
                property int netSignal: 0
                property bool btConnected: false
                property string batStatus: "Discharging"
                property int batLevel: 100
                
                onRightStateChanged: {
                    if (rightState === "idle") activeMenuHandle = null
                }

                Process {
                    id: batteryProcess
                    command: [Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/watchers/battery_fetch.sh"]
                    running: true
                    stdout: SplitParser {
                        onRead: data => {
                            let parts = data.trim().split(" ")
                            rightLiquidPill.batLevel = parseInt(parts[0])
                            rightLiquidPill.batStatus = parts.slice(1).join(" ")
                        }
                    }
                }
                Timer { interval: 5000; running: true; repeat: true; onTriggered: { if (!batteryProcess.running) batteryProcess.running = true } }

                Process {
                    id: networkProcess
                    command: [Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/watchers/network_fetch.sh"]
                    running: true
                    stdout: SplitParser {
                        onRead: data => {
                            let parts = data.trim().split(":::")
                            rightLiquidPill.netSsid = parts[0] === "disconnected" ? "" : parts[0]
                            rightLiquidPill.netSignal = parseInt(parts[1] || "0")
                            rightLiquidPill.btConnected = parts[2]?.trim() === "1"
                        }
                    }
                }
                Timer { interval: 3000; running: true; repeat: true; onTriggered: { if (!networkProcess.running) networkProcess.running = true } }

                Timer { id: openDelay; interval: 80; onTriggered: rightLiquidPill.rightState = "cc" }
                Timer { id: closeDelay; interval: 100; onTriggered: rightLiquidPill.rightState = "idle" }

                // Menu hover debounce timer
                Timer {
                    id: menuCloseTimer
                    interval: 350
                    onTriggered: {
                        if (!flyoutHover.hovered && !trayHover.hovered) {
                            rightLiquidPill.activeMenuHandle = null
                        }
                    }
                }

                mask: Region { item: rightContainer }

                Item {
                    id: rightContainer
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 0
                    anchors.rightMargin: 8

                    width: rightRow.width
                    height: rightRow.height

                    property bool keepOpen: pillHover.hovered || trayHover.hovered || flyoutHover.hovered
                    onKeepOpenChanged: {
                        if (keepOpen) {
                            closeDelay.stop()
                            openDelay.restart()
                        } else {
                            openDelay.stop()
                            closeDelay.restart()
                        }
                    }

                    Row {
                        id: rightRow
                        anchors.top: parent.top
                        anchors.right: parent.right
                        layoutDirection: Qt.RightToLeft
                        
                        spacing: 0 

                        // Main control center pill
                        Rectangle {
                            id: pillBackground
                            
                            color: Theme.surface
                            clip: true

                            width: rightLiquidPill.rightState === "idle" ? idleContent.implicitWidth + 24 : 340
                            height: rightLiquidPill.rightState === "idle" ? 30 : ccContent.implicitHeight + 32
                            
                            Behavior on width { NumberAnimation { duration: rightLiquidPill.rightState === "idle" ? 200 : 400; easing.type: Easing.OutExpo } }
                            Behavior on height { NumberAnimation { duration: rightLiquidPill.rightState === "idle" ? 200 : 400; easing.type: Easing.OutExpo } }

                            topLeftRadius: 0
                            topRightRadius: 0
                            bottomLeftRadius: rightLiquidPill.rightState === "idle" ? 12 : 16
                            bottomRightRadius: rightLiquidPill.rightState === "idle" ? 12 : 16
                            
                            Behavior on bottomLeftRadius { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                            Behavior on bottomRightRadius { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

                            HoverHandler { id: pillHover }

                            Row {
                                id: idleContent
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 4
                                anchors.rightMargin: 12
                                height: 22
                                spacing: 12

                                property bool isActive: rightLiquidPill.rightState === "idle"
                                visible: isActive; opacity: isActive ? 1 : 0
                                Behavior on opacity { 
                                    SequentialAnimation {
                                        PauseAnimation { duration: idleContent.isActive ? 300 : 0 }
                                        NumberAnimation { duration: idleContent.isActive ? 150 : 0; easing.type: Easing.OutQuad }
                                    }
                                }

                                Row {
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: {
                                            if (rightLiquidPill.netSsid === "") return "󰤭";
                                            if (rightLiquidPill.netSignal > 80) return "󰤨";
                                            if (rightLiquidPill.netSignal > 60) return "󰤥";
                                            if (rightLiquidPill.netSignal > 40) return "󰤢";
                                            if (rightLiquidPill.netSignal > 20) return "󰤟";
                                            return "󰤯";
                                        }
                                        color: rightLiquidPill.netSsid !== "" ? Theme.accent : Theme.danger
                                        font.pixelSize: 15
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
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
                                    Text { text: rightLiquidPill.batLevel + "%"; color: Theme.text; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }

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
                                netSignal: rightLiquidPill.netSignal
                                batLevel: rightLiquidPill.batLevel
                                batStatus: rightLiquidPill.batStatus
                                btConnected: rightLiquidPill.btConnected

                                property bool isActive: rightLiquidPill.rightState === "cc"
                                visible: isActive; opacity: isActive ? 1 : 0
                                Behavior on opacity {
                                    SequentialAnimation {
                                        PauseAnimation { duration: ccContent.isActive ? 100 : 0 }
                                        NumberAnimation { duration: ccContent.isActive ? 250 : 50; easing.type: Easing.OutQuad }
                                    }
                                }
                            }
                        }

                        // Vertical system tray
                        Item {
                            id: trayTabWrapper
                            property bool isOpen: rightLiquidPill.rightState === "cc" && SystemTray.items.values.length > 0
                            width: isOpen ? 44 : 0
                            height: Math.max(pillBackground.height, trayBackgroundWrapper.height)
                            clip: true

                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

                            Rectangle {
                                id: trayBackgroundWrapper
                                width: 44
                                height: trayColumnItems.implicitHeight + 16
                                y: 16 
                                
                                color: Theme.surface
                                
                                topLeftRadius: rightLiquidPill.isMenuOpen ? 0 : 22
                                topRightRadius: 0
                                bottomLeftRadius: rightLiquidPill.isMenuOpen ? 0 : 22
                                bottomRightRadius: 0

                                Behavior on topLeftRadius { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
                                Behavior on bottomLeftRadius { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 1
                                    color: rightLiquidPill.isMenuOpen ? Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.15) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 1
                                    color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.1)
                                }

                                HoverHandler { id: trayHover }

                                Column {
                                    id: trayColumnItems
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Repeater {
                                        model: SystemTray.items

                                        Rectangle {
                                            required property var modelData
                                            width: 24; height: 24; radius: 6 
                                            color: iconHover.hovered || rightLiquidPill.activeMenuHandle === modelData.menu ? Theme.surfaceHover : "transparent"
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Image {
                                                anchors.centerIn: parent
                                                source: modelData.icon
                                                width: 18; height: 18 
                                                sourceSize: Qt.size(18, 18)
                                            }

                                            HoverHandler { 
                                                id: iconHover
                                                cursorShape: Qt.PointingHandCursor 
                                                
                                                onHoveredChanged: {
                                                    if (hovered) {
                                                        menuCloseTimer.stop()
                                                        if (modelData.hasMenu) {
                                                            rightLiquidPill.activeMenuHandle = modelData.menu
                                                            rightLiquidPill.activeMenuName = modelData.title || modelData.id
                                                            let localPos = parent.mapToItem(rightRow, 0, 0)
                                                            rightLiquidPill.activeMenuY = localPos.y
                                                            
                                                            menuStack.clear()
                                                            menuStack.push(customMenuComponent, { handle: modelData.menu, appName: rightLiquidPill.activeMenuName })
                                                        } else {
                                                            rightLiquidPill.activeMenuHandle = null
                                                        }
                                                    } else {
                                                        menuCloseTimer.restart()
                                                    }
                                                }
                                            }
                                            
                                            TapHandler {
                                                acceptedButtons: Qt.LeftButton
                                                onTapped: modelData.activate()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Expandable sidecar menu
                        Item {
                            id: flyoutContainerWrapper
                            width: flyoutClip.width
                            height: Math.max(pillBackground.height, flyoutClip.y + flyoutClip.height)

                            Item {
                                id: flyoutClip
                                width: rightLiquidPill.isMenuOpen ? 220 : 0
                                height: flyoutBackground.height
                                
                                y: rightLiquidPill.activeMenuY
                                clip: true

                                Behavior on width { 
                                    SequentialAnimation {
                                        PauseAnimation { duration: rightLiquidPill.isMenuOpen ? 0 : 100 }
                                        NumberAnimation { duration: 250; easing.type: Easing.OutExpo }
                                    } 
                                }
                                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                Rectangle {
                                    id: flyoutBackground
                                    anchors.right: parent.right
                                    width: 220
                                    
                                    height: Math.min(Math.max(menuStack.currentItem?.implicitHeight || 100, 50), 450)
                                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                                    topLeftRadius: 12
                                    bottomLeftRadius: 12
                                    topRightRadius: 0
                                    bottomRightRadius: 0

                                    color: Theme.surface
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: Qt.rgba(0, 0, 0, 0.03) 
                                    }

                                    border.width: 1
                                    border.color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.15)

                                    HoverHandler {
                                        id: flyoutHover
                                        onHoveredChanged: {
                                            if (hovered) menuCloseTimer.stop()
                                            else menuCloseTimer.restart()
                                        }
                                    }

                                    StackView {
                                        id: menuStack
                                        anchors.fill: parent
                                        clip: true
                                        
                                        // Speed up the text sliding animations so they don't fight the new mechanical fold
                                        pushEnter: Transition { NumberAnimation { property: "x"; from: menuStack.width; to: 0; duration: 150; easing.type: Easing.OutCubic } }
                                        pushExit: Transition { NumberAnimation { property: "x"; from: 0; to: -menuStack.width; duration: 150; easing.type: Easing.OutCubic } }
                                        popEnter: Transition { NumberAnimation { property: "x"; from: -menuStack.width; to: 0; duration: 150; easing.type: Easing.OutCubic } }
                                        popExit: Transition { NumberAnimation { property: "x"; from: 0; to: menuStack.width; duration: 150; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Reusable menu component
                Component {
                    id: customMenuComponent

                    Item {
                        required property QsMenuHandle handle
                        required property string appName

                        implicitHeight: menuColumn.implicitHeight + 20

                        Column {
                            id: menuColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Row {
                                spacing: 8
                                Rectangle {
                                    width: 24; height: 24; radius: 6
                                    color: backHover.hovered ? Theme.surfaceHover : "transparent"
                                    Text { anchors.centerIn: parent; text: ""; color: Theme.text; font.pixelSize: 12 } 
                                    HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: menuStack.pop() }
                                }
                                Text {
                                    text: appName
                                    color: Theme.text; font.pixelSize: 13; font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2) }

                            QsMenuOpener { id: menuOpener; menu: handle }

                            ListView {
                                width: parent.width
                                height: contentHeight
                                model: menuOpener.children
                                clip: true
                                spacing: 2
                                interactive: false 
                                
                                delegate: Rectangle {
                                    required property var modelData
                                    width: parent ? parent.width : 0
                                    height: modelData.isSeparator ? 1 : 28 
                                    radius: 6
                                    color: modelData.isSeparator ? Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.15) : (menuItemHover.hovered ? Theme.surfaceHover : "transparent")

                                    Row {
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 8
                                        visible: !modelData.isSeparator

                                        Image {
                                            source: modelData.icon || ""
                                            width: 14; height: 14; sourceSize: Qt.size(14, 14)
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: modelData.icon !== ""
                                        }
                                        
                                        Text {
                                            text: modelData.text || ""
                                            color: modelData.enabled ? Theme.text : Theme.subtext
                                            font.pixelSize: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                        text: "" 
                                        color: Theme.subtext; font.pixelSize: 10
                                        visible: modelData.hasChildren && !modelData.isSeparator
                                    }

                                    HoverHandler { id: menuItemHover; enabled: !modelData.isSeparator && modelData.enabled; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        enabled: !modelData.isSeparator && modelData.enabled
                                        onTapped: {
                                            if (modelData.hasChildren) {
                                                menuStack.push(customMenuComponent, { handle: modelData, appName: modelData.text.replace(/&/g, '') })
                                            } else {
                                                modelData.triggered()
                                                menuStack.pop(null) 
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}