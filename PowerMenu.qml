import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

WlrLayershell {
    id: powerRoot
    
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    
    layer: WlrLayer.Overlay
    keyboardFocus: WlrKeyboardFocus.Exclusive 
    color: "transparent"
    
    property bool isOpen: false
    property string uptimeString: "Fetching..."
    
    property int currentIndex: 0
    property real contentOpacity: 0.0 
    
    signal requestClose()
    
    visible: isOpen || openAnim.running || closeAnim.running

    Window.onActiveChanged: {
        if (!Window.active && isOpen) {
            requestClose()
        }
    }

    Process {
        id: uptimeProcess
        command: ["uptime", "-p"]
        stdout: StdioCollector {
            onStreamFinished: {
                powerRoot.uptimeString = text.trim().replace("up ", "")
            }
        }
    }

    Process { id: actionProcess }

    function doAction(cmd) {
        actionProcess.command = ["bash", "-c", cmd]
        actionProcess.running = true
        requestClose()
    }

    onIsOpenChanged: {
        if (isOpen) {
            uptimeProcess.running = true
            currentIndex = 0 
            focusCatcher.forceActiveFocus() 
            closeAnim.stop()
            openAnim.restart()
        } else {
            openAnim.stop()
            closeAnim.restart()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: requestClose()
    }

    Item {
        id: focusCatcher
        focus: true
        
        Keys.onRightPressed: powerRoot.currentIndex = (powerRoot.currentIndex + 1) % 5
        Keys.onLeftPressed: powerRoot.currentIndex = (powerRoot.currentIndex + 4) % 5
        Keys.onEscapePressed: powerRoot.requestClose()
        
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                let actions = [
                    "hyprctl dispatch global quickshell:triggerSessionLock",
                    "hyprctl dispatch exit",
                    "systemctl suspend",
                    "systemctl reboot",
                    "systemctl poweroff"
                ]
                powerRoot.doAction(actions[powerRoot.currentIndex])
                event.accepted = true
            }
        }
    }

    Item {
        id: panelContainer
        width: 680
        height: 220
        anchors.centerIn: parent

        Rectangle {
            id: leftBlock
            color: Theme.surface
            clip: true
            
            property real outerRad: 24
            property real innerRad: 24
            topLeftRadius: outerRad
            bottomLeftRadius: outerRad
            topRightRadius: innerRad
            bottomRightRadius: innerRad
        }

        Rectangle {
            id: rightBlock
            color: Theme.surface
            clip: true
            
            property real outerRad: 24
            property real innerRad: 24
            topRightRadius: outerRad
            bottomRightRadius: outerRad
            topLeftRadius: innerRad
            bottomLeftRadius: innerRad
        }

        Item {
            id: mainContent
            width: 680
            height: 220
            anchors.centerIn: parent
            opacity: powerRoot.contentOpacity 

            Rectangle {
                anchors.fill: parent
                radius: 24
                color: "transparent"
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.05)
            }

            Column {
                anchors.centerIn: parent
                spacing: 24

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    Rectangle {
                        property bool isActive: lockHover.hovered || powerRoot.currentIndex === 0
                        width: 110; height: 110; radius: 16
                        color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent"
                        border.width: 2; border.color: isActive ? Theme.accent : Theme.surfaceHover
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        Column {
                            anchors.centerIn: parent; spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰌾"; color: parent.parent.isActive ? Theme.accent : Theme.text; font.pixelSize: 32 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Lock"; color: parent.parent.isActive ? Theme.accent : Theme.subtext; font.pixelSize: 14; font.bold: true }
                        }
                        HoverHandler { id: lockHover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) powerRoot.currentIndex = 0 }
                        TapHandler { onTapped: doAction("hyprctl dispatch global quickshell:triggerSessionLock") }
                    }

                    Rectangle {
                        property bool isActive: logoutHover.hovered || powerRoot.currentIndex === 1
                        width: 110; height: 110; radius: 16
                        color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent"
                        border.width: 2; border.color: isActive ? Theme.accent : Theme.surfaceHover
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        Column {
                            anchors.centerIn: parent; spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰍃"; color: parent.parent.isActive ? Theme.accent : Theme.text; font.pixelSize: 32 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Logout"; color: parent.parent.isActive ? Theme.accent : Theme.subtext; font.pixelSize: 14; font.bold: true }
                        }
                        HoverHandler { id: logoutHover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) powerRoot.currentIndex = 1 }
                        TapHandler { onTapped: doAction("hyprctl dispatch exit") }
                    }

                    Rectangle {
                        property bool isActive: suspendHover.hovered || powerRoot.currentIndex === 2
                        width: 110; height: 110; radius: 16
                        color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent"
                        border.width: 2; border.color: isActive ? Theme.accent : Theme.surfaceHover
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        Column {
                            anchors.centerIn: parent; spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰤄"; color: parent.parent.isActive ? Theme.accent : Theme.text; font.pixelSize: 32 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Suspend"; color: parent.parent.isActive ? Theme.accent : Theme.subtext; font.pixelSize: 14; font.bold: true }
                        }
                        HoverHandler { id: suspendHover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) powerRoot.currentIndex = 2 }
                        TapHandler { onTapped: doAction("systemctl suspend") }
                    }

                    Rectangle {
                        property bool isActive: rebootHover.hovered || powerRoot.currentIndex === 3
                        width: 110; height: 110; radius: 16
                        color: isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent"
                        border.width: 2; border.color: isActive ? Theme.accent : Theme.surfaceHover
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        Column {
                            anchors.centerIn: parent; spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰜉"; color: parent.parent.isActive ? Theme.accent : Theme.text; font.pixelSize: 32 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Reboot"; color: parent.parent.isActive ? Theme.accent : Theme.subtext; font.pixelSize: 14; font.bold: true }
                        }
                        HoverHandler { id: rebootHover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) powerRoot.currentIndex = 3 }
                        TapHandler { onTapped: doAction("systemctl reboot") }
                    }

                    Rectangle {
                        property bool isActive: powerHover.hovered || powerRoot.currentIndex === 4
                        width: 110; height: 110; radius: 16
                        color: isActive ? Theme.danger : "transparent"
                        border.width: 2; border.color: isActive ? Theme.danger : Theme.surfaceHover
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        Column {
                            anchors.centerIn: parent; spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰐥"; color: parent.parent.isActive ? "white" : Theme.danger; font.pixelSize: 32 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Power Off"; color: parent.parent.isActive ? "white" : Theme.text; font.pixelSize: 14; font.bold: true }
                        }
                        HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) powerRoot.currentIndex = 4 }
                        TapHandler { onTapped: doAction("systemctl poweroff") }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰔚  Uptime: " + powerRoot.uptimeString
                    color: Theme.subtext
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }
    }

    SequentialAnimation {
        id: openAnim
        
        ScriptAction {
            script: {
                let offScreenY = -(powerRoot.height / 2) - 100;
                
                leftBlock.x = 316; leftBlock.width = 48; leftBlock.y = offScreenY; leftBlock.height = 48;
                rightBlock.x = 316; rightBlock.width = 48; rightBlock.y = offScreenY; rightBlock.height = 48;
                
                leftBlock.outerRad = 24; leftBlock.innerRad = 24;
                rightBlock.outerRad = 24; rightBlock.innerRad = 24;
                
                powerRoot.contentOpacity = 0.0;
            }
        }

        ParallelAnimation {
            NumberAnimation { target: leftBlock; property: "y"; to: 86; duration: 350; easing.type: Easing.OutExpo }
            NumberAnimation { target: rightBlock; property: "y"; to: 86; duration: 350; easing.type: Easing.OutExpo }
        }

        ParallelAnimation {
            NumberAnimation { target: leftBlock; property: "x"; to: 0; duration: 350; easing.type: Easing.OutExpo }
            NumberAnimation { target: leftBlock; property: "width"; to: 340; duration: 350; easing.type: Easing.OutExpo }
            NumberAnimation { target: rightBlock; property: "x"; to: 340; duration: 350; easing.type: Easing.OutExpo } 
            NumberAnimation { target: rightBlock; property: "width"; to: 340; duration: 350; easing.type: Easing.OutExpo }
            
            NumberAnimation { target: leftBlock; property: "y"; to: 0; duration: 350; easing.type: Easing.OutExpo }
            NumberAnimation { target: rightBlock; property: "y"; to: 0; duration: 350; easing.type: Easing.OutExpo }
            NumberAnimation { target: leftBlock; property: "height"; to: 220; duration: 350; easing.type: Easing.OutExpo }
            NumberAnimation { target: rightBlock; property: "height"; to: 220; duration: 350; easing.type: Easing.OutExpo }
            
            NumberAnimation { target: leftBlock; property: "innerRad"; to: 0; duration: 350; easing.type: Easing.OutCubic }
            NumberAnimation { target: rightBlock; property: "innerRad"; to: 0; duration: 350; easing.type: Easing.OutCubic }
        }

        NumberAnimation { target: powerRoot; property: "contentOpacity"; to: 1.0; duration: 150; easing.type: Easing.OutSine }
        ScriptAction { script: focusCatcher.forceActiveFocus() }
    }

    SequentialAnimation {
        id: closeAnim
        
        NumberAnimation { target: powerRoot; property: "contentOpacity"; to: 0.0; duration: 100; easing.type: Easing.OutSine }
        
        ParallelAnimation {
            NumberAnimation { target: leftBlock; property: "width"; to: 48; duration: 250; easing.type: Easing.OutQuad }
            NumberAnimation { target: rightBlock; property: "width"; to: 48; duration: 250; easing.type: Easing.OutQuad }
            
            NumberAnimation { target: leftBlock; property: "height"; to: 48; duration: 250; easing.type: Easing.OutQuad }
            NumberAnimation { target: rightBlock; property: "height"; to: 48; duration: 250; easing.type: Easing.OutQuad }
            
            NumberAnimation { target: leftBlock; property: "y"; to: 86; duration: 250; easing.type: Easing.OutQuad }
            NumberAnimation { target: rightBlock; property: "y"; to: 86; duration: 250; easing.type: Easing.OutQuad }
            
            NumberAnimation { target: leftBlock; property: "innerRad"; to: 24; duration: 250; easing.type: Easing.OutQuad }
            NumberAnimation { target: rightBlock; property: "innerRad"; to: 24; duration: 250; easing.type: Easing.OutQuad }

            NumberAnimation { target: leftBlock; property: "x"; to: -60; duration: 250; easing.type: Easing.OutQuad }
            NumberAnimation { target: rightBlock; property: "x"; to: 692; duration: 250; easing.type: Easing.OutQuad } 
        }

        ParallelAnimation {
            NumberAnimation { target: leftBlock; property: "x"; to: -Screen.width; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: rightBlock; property: "x"; to: Screen.width; duration: 200; easing.type: Easing.InCubic }
        }
    }
}