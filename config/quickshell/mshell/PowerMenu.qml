import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
    exclusiveZone: -1
    color: Qt.rgba(0, 0, 0, 0.4 * contentOpacity)
    
    property bool isOpen: false
    property string uptimeString: "Fetching..."
    
    property int currentIndex: 0
    property real contentOpacity: 0.0 
    
    signal requestClose()
    
    visible: isOpen || openAnim.running || closeAnim.running

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

    function doAction(type, cmd, arg = "") {
        if (type === "hyprland") {
            Hyprland.dispatch(cmd, arg)
        } else if (type === "system") {
            actionProcess.command = ["bash", "-c", cmd + " > /dev/null 2>&1"]
            actionProcess.running = true
        }
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
            rebootBtn.stopHold(false)
            powerBtn.stopHold(false)
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
        property bool hasHadFocus: false 
        
        Window.onActiveChanged: {
            if (Window.active) {
                hasHadFocus = true 
            } else if (hasHadFocus && powerRoot.isOpen) {
                powerRoot.requestClose()
                hasHadFocus = false
            }
        }
        
        Keys.onRightPressed: powerRoot.currentIndex = (powerRoot.currentIndex + 1) % 5
        Keys.onLeftPressed: powerRoot.currentIndex = (powerRoot.currentIndex + 4) % 5
        Keys.onEscapePressed: powerRoot.requestClose()
        
        Keys.onPressed: (event) => {
            if (event.isAutoRepeat) return; 
            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (powerRoot.currentIndex === 0) powerRoot.doAction("hyprland", "global", "quickshell:triggerSessionLock")
                else if (powerRoot.currentIndex === 1) powerRoot.doAction("hyprland", "exit")
                else if (powerRoot.currentIndex === 2) powerRoot.doAction("system", "systemctl suspend")
                else if (powerRoot.currentIndex === 3) rebootBtn.startHold()
                else if (powerRoot.currentIndex === 4) powerBtn.startHold()
                
                event.accepted = true
            }
        }
        
        Keys.onReleased: (event) => {
            if (event.isAutoRepeat) return;
            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (powerRoot.currentIndex === 3) rebootBtn.stopHold(true)
                else if (powerRoot.currentIndex === 4) powerBtn.stopHold(true)
                
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

                    // Lock
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
                        TapHandler { onTapped: doAction("hyprland", "global", "quickshell:triggerSessionLock") }
                    }

                    // Logout
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
                        TapHandler { onTapped: doAction("hyprland", "exit") }
                    }

                    // Suspend
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
                        TapHandler { onTapped: doAction("system", "systemctl suspend") }
                    }

                    // Reboot
                    Rectangle {
                        id: rebootBtn
                        property bool isActive: rebootMouse.containsMouse || powerRoot.currentIndex === 3
                        property real holdProgress: 0.0
                        property bool showHoldMessage: false
                        
                        width: 110; height: 110; radius: 16
                        color: isActive && holdProgress === 0 ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent"
                        border.width: 2; border.color: isActive ? Theme.accent : Theme.surfaceHover
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        // Masked Container for the Liquid Wave
                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: rebootMask }

                            Rectangle {
                                id: rebootMask
                                anchors.fill: parent
                                radius: 16
                                color: "black"
                                visible: false
                                layer.enabled: true
                            }

                            Canvas {
                                id: rebootWave
                                anchors.fill: parent
                                property real wavePhase: 0
                                property real progress: rebootBtn.holdProgress

                                Timer {
                                    interval: 16
                                    running: rebootWave.progress > 0 && rebootWave.progress < 1
                                    repeat: true
                                    onTriggered: { rebootWave.wavePhase -= 0.15; rebootWave.requestPaint() }
                                }

                                onProgressChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    if (progress <= 0) return;

                                    let amp = 6 * Math.sin(progress * Math.PI); 
                                    let freq = 0.05;
                                    let baseY = height - (height * progress);

                                    ctx.fillStyle = Theme.accent;
                                    ctx.beginPath();
                                    ctx.moveTo(0, height);
                                    ctx.lineTo(0, baseY);

                                    for (let x = 0; x <= width; x += 3) {
                                        ctx.lineTo(x, baseY + Math.sin(x * freq + wavePhase) * amp);
                                    }

                                    ctx.lineTo(width, height);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                            }
                        }

                        Timer {
                            id: rebootMsgTimer
                            interval: 1000
                            onTriggered: rebootBtn.showHoldMessage = false
                        }
                        
                        function startHold() { rebootAnim.start() }
                        function stopHold(wasReleasedEarly) { 
                            if (wasReleasedEarly && holdProgress > 0 && holdProgress < 0.95) {
                                rebootRejectAnim.restart()
                                showHoldMessage = true
                                rebootMsgTimer.restart()
                            } else if (!wasReleasedEarly) {
                                showHoldMessage = false
                                rebootMsgTimer.stop()
                            }
                            rebootAnim.stop(); 
                            holdProgress = 0.0 
                        }
                        
                        NumberAnimation {
                            id: rebootAnim
                            target: rebootBtn
                            property: "holdProgress"
                            from: 0.0; to: 1.0; duration: 1200
                            easing.type: Easing.InOutSine 
                            onStopped: {
                                if (rebootBtn.holdProgress >= 0.99) powerRoot.doAction("system", "systemctl reboot")
                                rebootBtn.holdProgress = 0.0
                            }
                        }

                        SequentialAnimation {
                            id: rebootRejectAnim
                            NumberAnimation { target: rebootIcon; property: "anchors.horizontalCenterOffset"; from: 0; to: -6; duration: 40; easing.type: Easing.OutQuad }
                            NumberAnimation { target: rebootIcon; property: "anchors.horizontalCenterOffset"; from: -6; to: 6; duration: 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: rebootIcon; property: "anchors.horizontalCenterOffset"; from: 6; to: -4; duration: 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: rebootIcon; property: "anchors.horizontalCenterOffset"; from: -4; to: 4; duration: 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: rebootIcon; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40; easing.type: Easing.InQuad }
                        }
                        
                        Column {
                            anchors.centerIn: parent; spacing: 8
                            z: 2 
                            Text { 
                                id: rebootIcon
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.horizontalCenterOffset: 0
                                text: "󰜉"; font.pixelSize: 32; 
                                color: rebootBtn.holdProgress > 0.45 ? Theme.background : (rebootBtn.isActive ? Theme.accent : Theme.text); 
                                Behavior on color { ColorAnimation { duration: 150 } } 
                            }
                            Item {
                                width: 60; height: 16
                                anchors.horizontalCenter: parent.horizontalCenter
                                
                                Text { 
                                    anchors.centerIn: parent; text: "Reboot"; font.pixelSize: 14; font.bold: true; 
                                    color: rebootBtn.holdProgress > 0.45 ? Theme.background : (rebootBtn.isActive ? Theme.accent : Theme.subtext); 
                                    opacity: (rebootBtn.showHoldMessage || rebootAnim.running) ? 0 : 1
                                    Behavior on color { ColorAnimation { duration: 150 } } 
                                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                                }
                                Text { 
                                    anchors.centerIn: parent; text: "Hold..."; font.pixelSize: 14; font.bold: true; 
                                    color: rebootBtn.holdProgress > 0.45 ? Theme.background : (rebootBtn.isActive ? Theme.accent : Theme.subtext); 
                                    opacity: (rebootBtn.showHoldMessage || rebootAnim.running) ? 1 : 0
                                    Behavior on color { ColorAnimation { duration: 150 } } 
                                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                                }
                            }
                        }
                        
                        MouseArea {
                            id: rebootMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: powerRoot.currentIndex = 3
                            onPressed: rebootBtn.startHold()
                            onReleased: rebootBtn.stopHold(true)
                            onCanceled: rebootBtn.stopHold(false)
                            onExited: rebootBtn.stopHold(false)
                        }
                    }

                    // Power Off
                    Rectangle {
                        id: powerBtn
                        property bool isActive: powerMouse.containsMouse || powerRoot.currentIndex === 4
                        property real holdProgress: 0.0
                        property bool showHoldMessage: false
                        
                        width: 110; height: 110; radius: 16
                        color: isActive && holdProgress === 0 ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.15) : "transparent"
                        border.width: 2; border.color: isActive ? Theme.danger : Theme.surfaceHover
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        // Masked Container for the Liquid Wave
                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: powerMask }

                            Rectangle {
                                id: powerMask
                                anchors.fill: parent
                                radius: 16
                                color: "black"
                                visible: false
                                layer.enabled: true
                            }

                            Canvas {
                                id: powerWave
                                anchors.fill: parent
                                property real wavePhase: 0
                                property real progress: powerBtn.holdProgress

                                Timer {
                                    interval: 16
                                    running: powerWave.progress > 0 && powerWave.progress < 1
                                    repeat: true
                                    onTriggered: { powerWave.wavePhase -= 0.15; powerWave.requestPaint() }
                                }

                                onProgressChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    if (progress <= 0) return;

                                    let amp = 6 * Math.sin(progress * Math.PI);
                                    let freq = 0.05;
                                    let baseY = height - (height * progress);

                                    ctx.fillStyle = Theme.danger;
                                    ctx.beginPath();
                                    ctx.moveTo(0, height);
                                    ctx.lineTo(0, baseY);

                                    for (let x = 0; x <= width; x += 3) {
                                        ctx.lineTo(x, baseY + Math.sin(x * freq + wavePhase) * amp);
                                    }

                                    ctx.lineTo(width, height);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                            }
                        }

                        Timer {
                            id: powerMsgTimer
                            interval: 1000
                            onTriggered: powerBtn.showHoldMessage = false
                        }
                        
                        function startHold() { powerAnim.start() }
                        function stopHold(wasReleasedEarly) { 
                            if (wasReleasedEarly && holdProgress > 0 && holdProgress < 0.95) {
                                powerRejectAnim.restart()
                                showHoldMessage = true
                                powerMsgTimer.restart()
                            } else if (!wasReleasedEarly) {
                                showHoldMessage = false
                                powerMsgTimer.stop()
                            }
                            powerAnim.stop(); 
                            holdProgress = 0.0 
                        }
                        
                        NumberAnimation {
                            id: powerAnim
                            target: powerBtn
                            property: "holdProgress"
                            from: 0.0; to: 1.0; duration: 1200
                            easing.type: Easing.InOutSine 
                            onStopped: {
                                if (powerBtn.holdProgress >= 0.99) powerRoot.doAction("system", "systemctl poweroff")
                                powerBtn.holdProgress = 0.0
                            }
                        }

                        SequentialAnimation {
                            id: powerRejectAnim
                            NumberAnimation { target: powerIcon; property: "anchors.horizontalCenterOffset"; from: 0; to: -6; duration: 40; easing.type: Easing.OutQuad }
                            NumberAnimation { target: powerIcon; property: "anchors.horizontalCenterOffset"; from: -6; to: 6; duration: 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: powerIcon; property: "anchors.horizontalCenterOffset"; from: 6; to: -4; duration: 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: powerIcon; property: "anchors.horizontalCenterOffset"; from: -4; to: 4; duration: 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: powerIcon; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40; easing.type: Easing.InQuad }
                        }
                        
                        Column {
                            anchors.centerIn: parent; spacing: 8
                            z: 2 
                            Text { 
                                id: powerIcon
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.horizontalCenterOffset: 0
                                text: "󰐥"; font.pixelSize: 32; 
                                color: powerBtn.holdProgress > 0.45 ? "white" : (powerBtn.isActive ? Theme.danger : Theme.text); 
                                Behavior on color { ColorAnimation { duration: 150 } } 
                            }
                            Item {
                                width: 70; height: 16
                                anchors.horizontalCenter: parent.horizontalCenter
                                
                                Text { 
                                    anchors.centerIn: parent; text: "Power Off"; font.pixelSize: 14; font.bold: true; 
                                    color: powerBtn.holdProgress > 0.45 ? "white" : (powerBtn.isActive ? Theme.danger : Theme.subtext); 
                                    opacity: (powerBtn.showHoldMessage || powerAnim.running) ? 0 : 1
                                    Behavior on color { ColorAnimation { duration: 150 } } 
                                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                                }
                                Text { 
                                    anchors.centerIn: parent; text: "Hold..."; font.pixelSize: 14; font.bold: true; 
                                    color: powerBtn.holdProgress > 0.45 ? "white" : (powerBtn.isActive ? Theme.danger : Theme.subtext); 
                                    opacity: (powerBtn.showHoldMessage || powerAnim.running) ? 1 : 0
                                    Behavior on color { ColorAnimation { duration: 150 } } 
                                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                                }
                            }
                        }
                        
                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: powerRoot.currentIndex = 4
                            onPressed: powerBtn.startHold()
                            onReleased: powerBtn.stopHold(true)
                            onCanceled: powerBtn.stopHold(false)
                            onExited: powerBtn.stopHold(false)
                        }
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
                let offScreenY = (Screen.height / 2) + 200;
                
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