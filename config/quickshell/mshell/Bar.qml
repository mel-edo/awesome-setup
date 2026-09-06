import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import "."


Scope {
    id: root

    property string netSsid: ""
    property int netSignal: 0
    property bool btConnected: false
    property int savedBriLevel: 50
    property string savedPowerProfile: "balanced"

    function dispatchWorkspace(workspaceId) {
        Hyprland.dispatch('hl.dsp.focus({ workspace = ' + workspaceId + '})')
    }

    property int batLevel: Math.round(UPower.displayDevice.percentage * 100)
    property string batStatus: {
        switch (UPower.displayDevice.state) {
            case UPowerDeviceState.Charging: return "Charging"
            case UPowerDeviceState.Discharging: return "Discharging"
            case UPowerDeviceState.FullyCharged: return "Full"
            case UPowerDeviceState.PendingCharge: return "Charging"
            case UPowerDeviceState.PendingDischarge: return "Discharging"
            default: return "Unknown"
        }
    }

    Process {
        id: globalNetworkProcess
        command: ["bash", "-c", Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/watchers/network_fetch.sh"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(":::")
                root.netSsid = parts[0] === "disconnected" ? "" : parts[0]
                root.netSignal = parseInt(parts[1] || "0")
                root.btConnected = parts[2]?.trim() === "1"
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: { if (!globalNetworkProcess.running) globalNetworkProcess.running = true } }

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
                                    onClicked: dispatchWorkspace(workspaceId)
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
                margins.left: 8 + (8 * 14 + 7 * 10 + 24) + 6
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
                keyboardFocus: WlrKeyboardFocus.OnDemand

                implicitWidth: 800
                implicitHeight: 800 

                // Component state
                property string rightState: "idle"
                property var activeMenuHandle: null
                property string activeMenuName: ""
                property real activeMenuY: 0
                property bool isMenuOpen: activeMenuHandle !== null && rightState === "cc"
                
                onRightStateChanged: {
                    if (rightState === "idle") activeMenuHandle = null
                }

                Timer { id: openDelay; interval: 80; onTriggered: rightLiquidPill.rightState = "cc" }
                Timer { id: closeDelay; interval: 100; onTriggered: rightLiquidPill.rightState = "idle" }

                Timer {
                    id: menuCloseTimer
                    interval: 350
                    onTriggered: {
                        if (!flyoutHover.hovered && !pillHover.hovered) {
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

                    property bool keepOpen: pillHover.hovered || flyoutHover.hovered
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

                        Rectangle {
                            id: pillBackground
                            
                            color: Theme.surface
                            clip: true

                            width: rightLiquidPill.rightState === "idle" ? idleContent.implicitWidth + 24 : 340
                            height: rightLiquidPill.rightState === "idle" ? 30 : (ccItem.implicitHeight + 32)
                            
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

                                state: rightLiquidPill.rightState === "idle" ? "visible" : "hidden"

                                states: [
                                    State {
                                        name: "visible"
                                        PropertyChanges { target: idleContent; opacity: 1.0; visible: true }
                                    },
                                    State {
                                        name: "hidden"
                                        PropertyChanges { target: idleContent; opacity: 0.0; visible: false }
                                    }
                                ]

                                transitions: [
                                    Transition {
                                        from: "visible"; to: "hidden"
                                        PropertyAction { target: idleContent; property: "visible"; value: false }
                                        PropertyAction { target: idleContent; property: "opacity"; value: 0.0 }
                                    },
                                    Transition {
                                        from: "hidden"; to: "visible"
                                        SequentialAnimation {
                                            PauseAnimation { duration: 300 }
                                            PropertyAction { target: idleContent; property: "visible"; value: true }
                                            NumberAnimation { target: idleContent; property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                                        }
                                    }
                                ]

                                Row {
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: {
                                            if (root.netSsid === "") return "󰤭";
                                            if (root.netSignal > 80) return "󰤨";
                                            if (root.netSignal > 60) return "󰤥";
                                            if (root.netSignal > 40) return "󰤢";
                                            if (root.netSignal > 20) return "󰤟";
                                            return "󰤯";
                                        }
                                        color: root.netSsid !== "" ? Theme.accent : Theme.danger
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
                                            if (root.batStatus === "Charging") return "󰂄"
                                            if (root.batLevel < 10) return "󰁺"
                                            if (root.batLevel < 30) return "󰁼"
                                            if (root.batLevel < 60) return "󰁿"
                                            if (root.batLevel < 90) return "󰂁"
                                            return "󰁹"
                                        }
                                        color: root.batStatus === "Charging" ? Theme.accent : (root.batLevel <= 20 ? Theme.danger : Theme.accent)
                                        font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text { text: root.batLevel + "%"; color: Theme.text; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                            ControlCenter {
                                id: ccItem
                                layer.enabled: true 
                                
                                width: 308 
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                state: rightLiquidPill.rightState === "cc" ? "visible" : "hidden"

                                states: [
                                    State {
                                        name: "visible"
                                        PropertyChanges { target: ccItem; opacity: 1.0; visible: true }
                                    },
                                    State {
                                        name: "hidden"
                                        PropertyChanges { target: ccItem; opacity: 0.0; visible: false }
                                    }
                                ]

                                transitions: [
                                    Transition {
                                        from: "hidden"; to: "visible"
                                        SequentialAnimation {
                                            PropertyAction { target: ccItem; property: "visible"; value: true }
                                            PauseAnimation { duration: 150 }
                                            NumberAnimation { target: ccItem; property: "opacity"; duration: 250; easing.type: Easing.OutQuad }
                                        }
                                    },
                                    Transition {
                                        from: "visible"; to: "hidden"
                                        SequentialAnimation {
                                            NumberAnimation { target: ccItem; property: "opacity"; duration: 100; easing.type: Easing.OutQuad }
                                            PropertyAction { target: ccItem; property: "visible"; value: false }
                                        }
                                    }
                                ]
                                isOpen: rightLiquidPill.rightState === "cc"
                                parentWindow: rightLiquidPill
                                netSsid: root.netSsid
                                netSignal: root.netSignal
                                batLevel: root.batLevel
                                batStatus: root.batStatus
                                btConnected: root.btConnected
                                briLevel: root.savedBriLevel
                                powerProfile: root.savedPowerProfile
                            }
                        }

                        // Expandable sidecar menu
                        Item {
                            id: flyoutContainerWrapper
                            width: flyoutClip.width
                            height: Math.max(pillBackground.height, flyoutClip.y + flyoutClip.height)

                            Item {
                                id: flyoutClip
                                anchors.right: parent.right
                                width: rightLiquidPill.isMenuOpen ? 228 : 0
                                height: flyoutBackground.height
                                y: rightLiquidPill.activeMenuY
                                clip: true

                                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                Rectangle {
                                    id: flyoutBackground
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    width: 220
                                    height: Math.min(Math.max(menuStack.currentItem?.implicitHeight || 80, 50), 450)
                                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }

                                    radius: 12
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
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            WlrLayershell {
                id: trayDrawerWindow
                required property var modelData
                screen: modelData
                
                anchors.right: true
                anchors.top: true
                anchors.bottom: true
                margins.top: 60 
                
                layer: WlrLayer.Top
                color: "transparent"
                exclusiveZone: 0
                implicitWidth: 380 
                mask: Region { item: trayRoot }
                
                visible: SystemTray.items.values.length > 0
                property bool keepOpen: false
                property var activeMenuHandle: null
                property string activeMenuId: ""
                property string activeMenuName: ""
                property real activeMenuY: 0
                property real activeMenuIconCenterY: 0
                property bool isMenuOpen: activeMenuHandle !== null
                Timer {
                    id: stateResetTimer
                    interval: 200 
                    onTriggered: {
                        trayDrawerWindow.keepOpen = false
                        trayDrawerWindow.activeMenuHandle = null
                        trayDrawerWindow.activeMenuId = ""
                    }
                }

                onActiveMenuHandleChanged: {
                    if (activeMenuHandle === null) menuStack.clear()
                }

                Item {
                    id: trayRoot
                    anchors.top: parent.top
                    anchors.right: parent.right
                    
                    width: flyoutContainer.width + trayContainer.width
                    height: Math.max(trayContainer.height, (trayDrawerWindow.isMenuOpen ? flyoutClip.y + flyoutBackground.height : 0))

                    HoverHandler {
                        id: masterHover
                        onHoveredChanged: {
                            if (hovered) {
                                stateResetTimer.stop()
                                trayDrawerWindow.keepOpen = true
                            } else {
                                stateResetTimer.restart()
                            }
                        }
                    }
                    Item {
                        id: flyoutContainer
                        anchors.top: parent.top
                        anchors.right: trayContainer.left 
                        anchors.rightMargin: 0
                        
                        width: flyoutClip.width + 6
                        height: parent.height

                        Item {
                            id: flyoutClip
                            anchors.right: parent.right
                            width: trayDrawerWindow.isMenuOpen ? 250 : 0
                            height: flyoutBackground.height
                            y: trayDrawerWindow.activeMenuY
                            clip: true

                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                            Rectangle {
                                id: flyoutBackground
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                width: 230
                                height: Math.min(Math.max(menuStack.currentItem?.implicitHeight || 80, 50), 450)
                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }

                                radius: 12
                                color: Theme.surface
                                border.width: 1
                                border.color: Theme.highlight

                                Item {
                                    anchors.verticalCenter: parent.top
                                    anchors.verticalCenterOffset: Math.max(16, Math.min(parent.height - 16, trayDrawerWindow.activeMenuIconCenterY - flyoutClip.y))
                                    anchors.horizontalCenter: parent.right
                                    anchors.horizontalCenterOffset: 1
                                    width: 20; height: 20
                                    visible: trayDrawerWindow.isMenuOpen
                                    z: 10

                                    // Diamond rotated 45 degrees
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 16; height: 16
                                        rotation: 45
                                        color: Theme.surface
                                        border.width: 1
                                        border.color: Theme.highlight
                                    }

                                    Rectangle {
                                        anchors.right: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 10
                                        color: Theme.surface
                                    }
                                }

                                StackView {
                                    id: menuStack
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    clip: true
                                    pushEnter: null
                                    pushExit: null
                                    popEnter: null
                                    popExit: null
                                }
                            }
                        }
                    }
                    Item {
                        id: trayContainer
                        anchors.top: parent.top
                        anchors.right: parent.right
                        
                        property int targetHeight: (SystemTray.items.values.length * 34) + 16
                        
                        width: trayDrawerWindow.keepOpen ? 50 : 5
                        height: trayDrawerWindow.keepOpen ? Math.max(targetHeight, 50) : 50
                        
                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                        Rectangle {
                            id: trayDrawer
                            anchors.fill: parent
                            color: Theme.surface

                            topLeftRadius: trayDrawerWindow.keepOpen ? 25 : 4
                            bottomLeftRadius: trayDrawerWindow.keepOpen ? 25 : 4
                            topRightRadius: 0
                            bottomRightRadius: 0

                            Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.leftMargin: 2 
                                anchors.verticalCenter: parent.verticalCenter
                                
                                height: 36
                                width: 2
                                radius: 2
                                color: Theme.accent
                                
                                opacity: trayDrawerWindow.keepOpen ? 0.0 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                            }

                            ListView {
                                id: trayList
                                anchors.fill: parent
                                anchors.margins: 12
                                interactive: false 
                                
                                opacity: trayDrawerWindow.keepOpen ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                                model: SystemTray.items
                                spacing: 8
                                clip: true
                                
                                delegate: Rectangle {
                                    id: trayItemDelegate
                                    required property var modelData
                                    width: 28; height: 28; radius: 7
                                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                                    
                                    color: iconHover.hovered ? Theme.surfaceHover : "transparent"
                                    border.width: 0
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Image {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: 1
                                        source: modelData.icon || ""
                                        width: 18; height: 18 
                                        sourceSize: Qt.size(18, 18)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        antialiasing: true
                                    }

                                    HoverHandler { 
                                        id: iconHover
                                        cursorShape: Qt.PointingHandCursor 
                                    }
                                    
                                    TapHandler {
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onTapped: (eventPoint, button) => {
                                            if (button === Qt.LeftButton) {
                                                modelData.activate()
                                                trayDrawerWindow.activeMenuHandle = null
                                                trayDrawerWindow.activeMenuId = ""
                                            } else if (button === Qt.RightButton) {
                                                if (modelData.hasMenu) {
                                                    if (trayDrawerWindow.activeMenuHandle !== modelData.menu) {
                                                        trayDrawerWindow.activeMenuHandle = modelData.menu
                                                        trayDrawerWindow.activeMenuName = (modelData.title || "Options").replace(/&/g, '')
                                                        
                                                        let localPos = trayItemDelegate.mapToItem(trayRoot, 0, 0)
                                                        trayDrawerWindow.activeMenuIconCenterY = localPos.y + trayItemDelegate.height / 2
                                                        trayDrawerWindow.activeMenuY = Math.max(6, Math.min(localPos.y - 12, trayRoot.height - 80))
                                                        
                                                        menuStack.clear()
                                                        menuStack.push(customMenuComponent, { handle: modelData.menu, appName: trayDrawerWindow.activeMenuName }, StackView.Immediate)
                                                    } else {
                                                        trayDrawerWindow.activeMenuHandle = null
                                                    }
                                                } else {
                                                    modelData.secondaryActivate()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
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

                            Item {
                                width: parent.width
                                height: 22

                                Rectangle {
                                    id: backBtn
                                    width: 22; height: 22; radius: 6
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: backHover.hovered ? Theme.surfaceHover : "transparent"
                                    visible: menuStack.depth > 1
                                    Text { anchors.centerIn: parent; text: ""; color: Theme.text; font.pixelSize: 11 } 
                                    HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: menuStack.pop() }
                                }

                                Text {
                                    text: appName
                                    color: Theme.accent
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: (menuStack.depth > 1) ? backBtn.right : parent.left
                                    anchors.leftMargin: (menuStack.depth > 1) ? 8 : 4
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle { 
                                width: parent.width
                                height: 1
                                color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2) 
                            }

                            QsMenuOpener { id: menuOpener; menu: handle }

                            ListView {
                                width: parent.width
                                height: contentHeight
                                model: menuOpener.children
                                clip: true
                                spacing: 2
                                interactive: false 
                                
                                delegate: Rectangle {
                                    id: menuItemRoot
                                    required property var modelData
                                    anchors.left: parent ? parent.left : undefined
                                    anchors.right: parent ? parent.right : undefined
                                    height: modelData.isSeparator ? 9 : 28 
                                    radius: 6
                                    color: modelData.isSeparator ? "transparent" : (menuItemHover.hovered ? Theme.surfaceHover : "transparent")

                                    readonly property bool isCheckable: modelData && modelData.buttonType > 0
                                    readonly property bool isChecked: isCheckable && (modelData.checkState === 2 || modelData.checkState === Qt.Checked)
                                    readonly property bool hasIcon: modelData && typeof modelData.icon === "string" && modelData.icon.length > 0

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width - 8
                                        height: 1
                                        color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2)
                                        visible: modelData.isSeparator
                                    }

                                    Item {
                                        anchors.fill: parent
                                        visible: !modelData.isSeparator

                                        Item {
                                            id: leadingSlot
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 16; height: 16
                                            visible: menuItemRoot.isCheckable || menuItemRoot.hasIcon

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰄬"
                                                color: Theme.accent
                                                font.pixelSize: 12
                                                font.bold: true
                                                visible: menuItemRoot.isChecked
                                            }

                                            IconImage {
                                                anchors.fill: parent
                                                source: menuItemRoot.hasIcon ? modelData.icon : ""
                                                visible: menuItemRoot.hasIcon && !menuItemRoot.isCheckable
                                            }
                                        }

                                        Text {
                                            id: itemLabel
                                            anchors.left: leadingSlot.visible ? leadingSlot.right : parent.left
                                            anchors.leftMargin: leadingSlot.visible ? 8 : 10
                                            anchors.right: hasChildArrow.visible ? hasChildArrow.left : parent.right
                                            anchors.rightMargin: hasChildArrow.visible ? 6 : 8
                                            anchors.verticalCenter: parent.verticalCenter

                                            text: (modelData.text || "").replace(/&/g, '')
                                            color: modelData.enabled ? Theme.text : Theme.subtext
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignLeft
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            id: hasChildArrow
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰅂" 
                                            color: Theme.subtext
                                            font.pixelSize: 11
                                            visible: modelData.hasChildren === true
                                        }
                                    }

                                    HoverHandler { id: menuItemHover; enabled: !modelData.isSeparator && modelData.enabled; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        enabled: !modelData.isSeparator && modelData.enabled
                                        onTapped: {
                                            if (modelData.hasChildren) {
                                                menuStack.push(customMenuComponent, { handle: modelData, appName: (modelData.text || "").replace(/&/g, '') }, StackView.Immediate)
                                            } else {
                                                modelData.triggered()
                                                trayDrawerWindow.activeMenuHandle = null
                                                trayDrawerWindow.activeMenuId = ""
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