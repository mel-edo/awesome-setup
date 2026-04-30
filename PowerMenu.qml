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
    keyboardFocus: WlrKeyboardFocus.OnDemand 
    color: "transparent"
    
    property bool isOpen: false
    property string uptimeString: "Fetching..."
    
    // Controls the fade-in of the buttons AFTER the box expands
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
            closeAnim.stop()
            openAnim.restart()
        } else {
            openAnim.stop()
            closeAnim.restart()
        }
    }

    // Invisible background to catch clicks and close safely
    MouseArea {
        anchors.fill: parent
        onClicked: requestClose()
    }

    // ─── THE ANIMATION CONTAINER ───────────────────────────────────────────
    Item {
        id: panelContainer
        width: 600
        height: 300
        anchors.centerIn: parent

        // 1. The Entrance Bullets (Visible only during entry/exit)
        Item {
            id: beamContainer
            anchors.fill: parent
            opacity: 1

            // Left Multi-colored Bullet
            Rectangle {
                id: leftBlock
                width: 80; height: 24
                y: 138 // Vertically centered in the 300px container
                x: -Screen.width
                radius: 12
                clip: true
                color: "transparent"
                
                Column {
                    anchors.fill: parent
                    Rectangle { width: parent.width; height: 8; color: Theme.highlight }
                    Rectangle { width: parent.width; height: 8; color: Theme.accent }
                    Rectangle { width: parent.width; height: 8; color: Theme.danger }
                }
            }

            // Right Multi-colored Bullet
            Rectangle {
                id: rightBlock
                width: 80; height: 24
                y: 138
                x: Screen.width
                radius: 12
                clip: true
                color: "transparent"
                
                Column {
                    anchors.fill: parent
                    Rectangle { width: parent.width; height: 8; color: Theme.highlight }
                    Rectangle { width: parent.width; height: 8; color: Theme.accent }
                    Rectangle { width: parent.width; height: 8; color: Theme.danger }
                }
            }
        }

        // 2. The Main Expanding Background
        Rectangle {
            id: mainBg
            width: 160   // Starts at the exact width of the 2 fused bullets
            height: 24   // Starts at bullet height
            radius: 12   
            anchors.centerIn: parent
            color: Theme.surface
            opacity: 0   // Hidden until bullets collide
            clip: true   // Masks the content inside while expanding

            // The fused stripes that stretch with the background
            Column {
                id: mainBgStripes
                anchors.centerIn: parent
                width: parent.width
                height: 24
                opacity: 1.0
                
                Rectangle { width: parent.width; height: 8; color: Theme.highlight }
                Rectangle { width: parent.width; height: 8; color: Theme.accent }
                Rectangle { width: parent.width; height: 8; color: Theme.danger }
            }

            // 3. The Actual Menu Content
            Item {
                id: mainContent
                width: 600
                height: 300
                anchors.centerIn: parent
                opacity: powerRoot.contentOpacity 

                Row {
                    anchors.fill: parent

                    // --- LEFT SIDE (Uptime, Lock, Logout) ---
                    Item {
                        width: 300; height: 300
                        Column {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 20

                            Column {
                                width: parent.width
                                spacing: 4
                                Text { text: "󰔚  Uptime"; color: Theme.accent; font.pixelSize: 14; font.bold: true }
                                Text { 
                                    text: powerRoot.uptimeString
                                    color: Theme.text
                                    font.pixelSize: 18
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.15) }

                            Row {
                                spacing: 16
                                
                                Rectangle {
                                    width: 110; height: 110; radius: 16
                                    color: lockHover.hovered ? Theme.surfaceHover : "transparent"
                                    border.width: 2; border.color: Theme.surfaceHover
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    
                                    Column {
                                        anchors.centerIn: parent; spacing: 8
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰌾"; color: Theme.text; font.pixelSize: 32 }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Lock"; color: Theme.subtext; font.pixelSize: 14; font.bold: true }
                                    }
                                    HoverHandler { id: lockHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: doAction("loginctl lock-session") }
                                }

                                Rectangle {
                                    width: 110; height: 110; radius: 16
                                    color: logoutHover.hovered ? Theme.surfaceHover : "transparent"
                                    border.width: 2; border.color: Theme.surfaceHover
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    
                                    Column {
                                        anchors.centerIn: parent; spacing: 8
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰍃"; color: Theme.text; font.pixelSize: 32 }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Logout"; color: Theme.subtext; font.pixelSize: 14; font.bold: true }
                                    }
                                    HoverHandler { id: logoutHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: doAction("hyprctl dispatch exit") }
                                }
                            }
                        }
                    }

                    // --- CENTER SEAM ---
                    Rectangle {
                        width: 1; height: 300 - 48
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.1)
                    }

                    // --- RIGHT SIDE (Power Actions) ---
                    Item {
                        width: 299; height: 300
                        Column {
                            anchors.fill: parent
                            anchors.margins: 24
                            anchors.leftMargin: 25
                            spacing: 20

                            Text { text: "Power Actions"; color: Theme.subtext; font.pixelSize: 14; font.bold: true }

                            Grid {
                                columns: 2
                                spacing: 16

                                Rectangle {
                                    width: 110; height: 95; radius: 16
                                    color: suspendHover.hovered ? Theme.surfaceHover : "transparent"
                                    border.width: 2; border.color: Theme.surfaceHover
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    
                                    Column {
                                        anchors.centerIn: parent; spacing: 8
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰤄"; color: Theme.text; font.pixelSize: 28 }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Suspend"; color: Theme.subtext; font.pixelSize: 12; font.bold: true }
                                    }
                                    HoverHandler { id: suspendHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: doAction("systemctl suspend") }
                                }

                                Rectangle {
                                    width: 110; height: 95; radius: 16
                                    color: rebootHover.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent"
                                    border.width: 2; border.color: rebootHover.hovered ? Theme.accent : Theme.surfaceHover
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    
                                    Column {
                                        anchors.centerIn: parent; spacing: 8
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰜉"; color: rebootHover.hovered ? Theme.accent : Theme.text; font.pixelSize: 28 }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Reboot"; color: rebootHover.hovered ? Theme.accent : Theme.subtext; font.pixelSize: 12; font.bold: true }
                                    }
                                    HoverHandler { id: rebootHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: doAction("systemctl reboot") }
                                }

                                Rectangle {
                                    width: 236; height: 95; radius: 16
                                    color: powerHover.hovered ? Theme.danger : "transparent"
                                    border.width: 2; border.color: powerHover.hovered ? Theme.danger : Theme.surfaceHover
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    
                                    Row {
                                        anchors.centerIn: parent; spacing: 12
                                        Text { text: "󰐥"; color: powerHover.hovered ? "white" : Theme.danger; font.pixelSize: 28; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "Power Off"; color: powerHover.hovered ? "white" : Theme.text; font.pixelSize: 16; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: doAction("systemctl poweroff") }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ─── SEQUENCED CHOREOGRAPHY ────────────────────────────────────────────
    SequentialAnimation {
        id: openAnim
        
        // 0. Reset state instantly
        ScriptAction {
            script: {
                leftBlock.x = -Screen.width;
                rightBlock.x = Screen.width;
                beamContainer.opacity = 1.0;
                mainBg.width = 160;
                mainBg.height = 24;
                mainBg.radius = 12;
                mainBgStripes.opacity = 1.0;
                mainBg.opacity = 0.0;
                powerRoot.contentOpacity = 0.0;
            }
        }

        // 1. Fly the bullets in to the center
        // Center is 300. Left bullet (width 80) stops at 220. Right bullet stops at 300.
        ParallelAnimation {
            NumberAnimation { target: leftBlock; property: "x"; to: 220; duration: 300; easing.type: Easing.OutExpo }
            NumberAnimation { target: rightBlock; property: "x"; to: 300; duration: 300; easing.type: Easing.OutExpo }
        }

        // 2. Seamlessly swap the separate bullets for the solid unified block
        ScriptAction { script: { mainBg.opacity = 1.0; beamContainer.opacity = 0.0; } }
        
        // 3. Stretch horizontally
        NumberAnimation { target: mainBg; property: "width"; to: 600; duration: 250; easing.type: Easing.OutExpo }

        // 4. Fade stripes & Expand Vertically
        ParallelAnimation {
            NumberAnimation { target: mainBgStripes; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.OutSine }
            NumberAnimation { target: mainBg; property: "height"; to: 300; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
            NumberAnimation { target: mainBg; property: "radius"; to: 24; duration: 300; easing.type: Easing.OutCubic }
        }

        // 5. Fade in the UI
        NumberAnimation { target: powerRoot; property: "contentOpacity"; to: 1.0; duration: 150; easing.type: Easing.OutSine }
    }

    SequentialAnimation {
        id: closeAnim
        
        // 1. Fade the UI elements out
        NumberAnimation { target: powerRoot; property: "contentOpacity"; to: 0.0; duration: 100; easing.type: Easing.OutSine }
        
        // 2. Collapse Vertically & Bring Stripes Back
        ParallelAnimation {
            NumberAnimation { target: mainBgStripes; property: "opacity"; to: 1.0; duration: 200; easing.type: Easing.OutSine }
            NumberAnimation { target: mainBg; property: "height"; to: 24; duration: 250; easing.type: Easing.InBack; easing.overshoot: 0.5 }
            NumberAnimation { target: mainBg; property: "radius"; to: 12; duration: 250; easing.type: Easing.InCubic }
        }

        // 3. Collapse Horizontally
        NumberAnimation { target: mainBg; property: "width"; to: 160; duration: 200; easing.type: Easing.InExpo }

        // 4. Swap solid block back to separate bullets
        ScriptAction { script: { mainBg.opacity = 0.0; beamContainer.opacity = 1.0; } }
        
        // 5. Throw bullets off screen
        ParallelAnimation {
            NumberAnimation { target: leftBlock; property: "x"; to: -Screen.width; duration: 300; easing.type: Easing.InExpo }
            NumberAnimation { target: rightBlock; property: "x"; to: Screen.width; duration: 300; easing.type: Easing.InExpo }
        }
    }
}