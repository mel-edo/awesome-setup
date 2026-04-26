import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import "."

Scope {
    id: root

    property string authBuffer: ""
    property string authStatus: "Enter password"

    IpcHandler {
        target: "lock"
        function triggerSessionLock(): void {
            sessionLock.locked = true
        }
    }

    PamContext {
        id: passwd
        config: "login"

        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.authBuffer)
                root.authBuffer = ""
            }
        }

        onCompleted: res => {
            if (res === PamResult.Success) {
                authStatus = "Unlocked"
                sessionLock.locked = false 
            } else {
                authStatus = "Incorrect password"
                errorShake.restart()
                passwd.start()
            }
        }
    }

    function handleKey(event) {
        if (!sessionLock.locked) return

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            passwd.start()
        } else if (event.key === Qt.Key_Backspace) {
            authBuffer = authBuffer.slice(0, -1)
        } else if (event.key === Qt.Key_Escape) {
            authBuffer = ""
        } else if (event.text.length === 1) {
            authBuffer += event.text
        }
        
        if (authStatus === "Incorrect password") authStatus = "Enter password"
    }

    WlSessionLock {
        id: sessionLock
        
        onLockedChanged: {
            if (locked) {
                authBuffer = ""
                authStatus = "Enter password"
                passwd.start()
            }
        }

        WlSessionLockSurface {
            id: lockSurface
            color: "black"

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => root.handleKey(event)

                Item {
                    id: bgContainer
                    anchors.fill: parent

                    // Fallback animated base gradient 
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "#060a14" }
                            GradientStop { position: 1.0; color: "#111827" }
                        }
                    }

                    Image {
                        id: bgImage
                        anchors.fill: parent
                        source: "file:///home/meledo/Pictures/Wallpapers/your-wallpaper.jpg" 
                        fillMode: Image.PreserveAspectCrop
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 1000 } }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 64
                            colorizationColor: "black"
                            colorization: 0.35
                        }
                    }

                    Repeater {
                        model: 75
                        Item {
                            property real px: Math.random() * lockSurface.width
                            property real py: Math.random() * lockSurface.height
                            property real sz: (1.0 + Math.random() * 3.0) 
                            property color pColor: Math.random() > 0.5 ? Theme.accent : "#ffffff"
                            
                            x: px; y: py

                            Rectangle {
                                width: parent.sz; height: width; radius: width / 2
                                color: parent.pColor
                                opacity: 0

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: Math.random() * 5000 }
                                    NumberAnimation { from: 0; to: Math.random() * 0.4 + 0.2; duration: 2000 + Math.random() * 2000; easing.type: Easing.OutQuad }
                                    NumberAnimation { from: Math.random() * 0.4 + 0.2; to: 0; duration: 3000 + Math.random() * 2000; easing.type: Easing.InQuad }
                                }
                                
                                NumberAnimation on y {
                                    from: parent.py; to: parent.py - Math.random() * 60 - 20
                                    duration: 10000 + Math.random() * 10000
                                    loops: Animation.Infinite
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#66060a14" }
                            GradientStop { position: 0.5; color: "transparent" }
                            GradientStop { position: 1.0; color: "#aa060a14" }
                        }
                    }
                }

                Item {
                    id: uiContainer
                    anchors.centerIn: parent
                    width: 360; height: 480
                    opacity: 0

                    Component.onCompleted: fadeIn.start()

                    NumberAnimation {
                        id: fadeIn
                        target: uiContainer; property: "opacity"
                        from: 0; to: 1; duration: 1200; easing.type: Easing.OutCubic
                    }

                    SequentialAnimation {
                        id: errorShake
                        NumberAnimation { target: uiContainer; property: "x"; from: uiContainer.x; to: uiContainer.x - 12; duration: 50 }
                        NumberAnimation { target: uiContainer; property: "x"; to: uiContainer.x + 12; duration: 50 }
                        NumberAnimation { target: uiContainer; property: "x"; to: uiContainer.x - 12; duration: 50 }
                        NumberAnimation { target: uiContainer; property: "x"; to: uiContainer.x; duration: 50 }
                    }

                    // Glassmorphism Card
                    Rectangle {
                        anchors.fill: parent
                        radius: 24
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.3)
                        border.width: 1
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 32
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 28

                        // User Profile
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 16

                            Item {
                                width: 110; height: 110
                                anchors.horizontalCenter: parent.horizontalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 55
                                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)
                                    border.width: 2; border.color: Theme.accent
                                    
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowOpacity: 0.4
                                        shadowColor: Theme.accent
                                        shadowBlur: 20
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Quickshell.env("USER") ? Quickshell.env("USER").charAt(0).toUpperCase() : ""
                                        font.pixelSize: 42
                                        font.bold: true
                                        color: Theme.accent
                                    }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Quickshell.env("USER") ? Quickshell.env("USER").toUpperCase() : "LOCKED"
                                color: Theme.text
                                font.pixelSize: 22
                                font.bold: true
                                font.letterSpacing: 2
                            }
                            Text {
                                text: "SYSTEM SECURED"
                                anchors.horizontalCenter: parent.horizontalCenter
                                font.pixelSize: 11
                                color: Theme.accent
                                opacity: 0.7
                                font.letterSpacing: 1.5
                            }
                        }

                        // Password Field Container
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 260; height: 44
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Qt.rgba(0, 0, 0, 0.3)
                                border.width: 1
                                border.color: root.authBuffer.length > 0 ? Theme.accent : Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2)
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    height: 18

                                    Repeater {
                                        model: root.authBuffer.length
                                        Text {
                                            text: "✦"
                                            font.pixelSize: 16
                                            color: Theme.accent
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 2; height: 18
                                        color: Theme.accent
                                        visible: root.authBuffer.length === 0
                                        SequentialAnimation on opacity {
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0; duration: 500 }
                                            NumberAnimation { to: 1; duration: 500 }
                                        }
                                    }
                                }
                            }
                        }

                        // Status Info
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 260; height: 20
                            Text {
                                anchors.centerIn: parent
                                text: root.authStatus === "Enter password" ? "Awaiting credentials..." : root.authStatus
                                color: root.authStatus === "Incorrect password" ? Theme.danger : Theme.subtext
                                font.pixelSize: 13
                                font.letterSpacing: 0.5
                                opacity: 0.8
                            }
                        }
                    }
                }
            }
        }
    }
}