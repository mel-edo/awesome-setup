import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam
import "."

Scope {
    id: root

    IpcHandler {
        target: "lock"
        function triggerSessionLock(): void {
            rootLock.locked = true
        }
    }

    GlobalShortcut {
        name: "triggerSessionLock"
        onPressed: rootLock.locked = true
    }

    readonly property color base:      Theme.background
    readonly property color crust:     Theme.surface
    readonly property color mantle:    Theme.surface
    readonly property color text:      Theme.text
    readonly property color subtext0:  Theme.subtext
    readonly property color overlay0:  Theme.surfaceHover
    readonly property color overlay2:  Theme.surfaceHover
    readonly property color surface0:  Theme.surface
    readonly property color surface1:  Theme.surfaceHover
    readonly property color surface2:  Theme.highlight

    readonly property color mauve:     Theme.accent
    readonly property color blue:      Theme.highlight
    readonly property color peach:     Theme.accentAlt
    readonly property color red:       Theme.danger
    readonly property color green:     "#a6e3a1"

    QtObject {
        id: lockUI
        property bool failed: false
        property bool authenticating: false
        property string statusText: "Locked"
        property string passwordBuffer: "" 
    }

    PamContext {
        id: pam
        config: "login"
        
        Component.onCompleted: pam.start()
        
        onResponseRequiredChanged: {
            if (responseRequired && lockUI.passwordBuffer !== "") {
                respond(lockUI.passwordBuffer);
                lockUI.passwordBuffer = "";
            }
        }
        
        onCompleted: (result) => {
            lockUI.authenticating = false;
            if (result === PamResult.Success) {
                rootLock.locked = false;
                lockUI.passwordBuffer = ""; 
            } else {
                lockUI.failed = true;
                lockUI.statusText = "Locked";
                lockUI.passwordBuffer = ""; 
                pam.start(); 
            }
        }
    }

    // System action processes
    Process { id: suspendProcess; command: ["systemctl", "suspend"] }
    Process { id: poweroffProcess; command: ["systemctl", "poweroff"] }
    Process { id: reloadProcess; command: ["systemctl", "reboot"] }

    WlSessionLock {
        id: rootLock
        locked: false

        WlSessionLockSurface {
            id: surface

            Item {
                id: screenRoot
                anchors.fill: parent

                property string staticWallpaperPath: "file:///tmp/lock_bg.png"
                property string batPct: "100"
                property string batStatus: "AC"
                property string currentUser: "User"
                property string faceIconPath: ""
                property string kbLayout: "US"
                property string weatherIcon: ""
                property string weatherTemp: "--°C"

                property real introState: 0.0
                property bool powerMenuOpen: false
                property bool inputActive: false
                property bool isPlayingIntro: true

                Component.onCompleted: {
                    introSequence.start()
                    forceActiveFocus()
                }

                // ROOT KEY HANDLER
                focus: true 
                Keys.onPressed: (event) => {
                    if (screenRoot.isPlayingIntro || lockUI.authenticating) return;

                    inputActive = true; 

                    if (event.key === Qt.Key_Escape) {
                        lockUI.passwordBuffer = "";
                    } else if (event.key === Qt.Key_Backspace) {
                        if (event.modifiers & Qt.ControlModifier) {
                            lockUI.passwordBuffer = "";
                        } else {
                            lockUI.passwordBuffer = lockUI.passwordBuffer.slice(0, -1);
                        }
                    } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        if (lockUI.passwordBuffer.length > 0) {
                            lockUI.authenticating = true;
                            lockUI.failed = false;
                            
                            if (pam.responseRequired) {
                                pam.respond(lockUI.passwordBuffer);
                                lockUI.passwordBuffer = "";
                            } else {
                                pam.start(); 
                            }
                        }
                    } else if (event.text.length > 0 && event.text !== "\t" && event.text !== "\n" && event.text !== "\r") {
                        lockUI.passwordBuffer += event.text;
                        lockUI.failed = false; 
                    }
                    event.accepted = true;
                }

                property real globalOrbitAngle: 0
                NumberAnimation on globalOrbitAngle {
                    from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
                }

                Timer {
                    id: idleTimer
                    interval: 15000
                    running: screenRoot.inputActive && lockUI.passwordBuffer.length === 0
                    repeat: false
                    onTriggered: screenRoot.inputActive = false
                }

                // BACKGROUND DATA POLLING
                Process {
                    id: userPoller
                    command: ["bash", "-c", "USER_VAR=$(whoami); ICON_PATH=\"\"; if [ -f ~/.face.icon ]; then ICON_PATH=$(readlink -f ~/.face.icon); elif [ -f ~/.face ]; then ICON_PATH=$(readlink -f ~/.face); fi; echo -n \"$USER_VAR|$ICON_PATH\""]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let parts = this.text.trim().split("|");
                            if (parts.length > 0 && parts[0] !== "") screenRoot.currentUser = parts[0];
                            if (parts.length > 1 && parts[1].trim() !== "") {
                                let path = parts[1].trim();
                                screenRoot.faceIconPath = path.startsWith("file://") ? path : "file://" + path;
                            }
                        }
                    }
                    Component.onCompleted: running = true
                }

                Process {
                    id: kbPoller
                    command: ["bash", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap' | head -n1 | cut -c1-2 | tr '[:lower:]' '[:upper:]'"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let layout = this.text.trim();
                            if (layout !== "" && layout !== "null") screenRoot.kbLayout = layout;
                        }
                    }
                }
                Timer { interval: 1500; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (!kbPoller.running) kbPoller.running = true } }

                Process {
                    id: batPoller
                    command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo '100'; cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1 || echo 'AC'"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let lines = this.text.trim().split("\n");
                            if (lines.length >= 2) {
                                screenRoot.batPct = lines[0] || "100";
                                screenRoot.batStatus = lines[1] || "Unknown";
                            }
                        }
                    }
                }
                Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (!batPoller.running) batPoller.running = true } }

                function weatherIconCode(code) {
                    if (!code) return "󰖙"
                    let isNight = code.endsWith("n")
                    if (code.startsWith("01")) return isNight ? "󰖔" : "󰖙" 
                    if (code.startsWith("02")) return isNight ? "" : "󰖕" 
                    if (code.startsWith("03") || code.startsWith("04")) return "󰖐" 
                    if (code.startsWith("09") || code.startsWith("10")) return "󰖗" 
                    if (code.startsWith("11")) return "󰖓" 
                    if (code.startsWith("13")) return "󰖘" 
                    if (code.startsWith("50")) return "󰖑" 
                    return isNight ? "󰖔" : "󰖙" 
                }

                Process {
                    id: weatherPoller
                    command: [Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/calendar/weather.sh"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                let data = JSON.parse(text)
                                if (data && data.today) {
                                    screenRoot.weatherIcon = screenRoot.weatherIconCode(data.today.icon)
                                    screenRoot.weatherTemp = Math.round(data.today.temp) + "°C"
                                }
                            } catch(e) {}
                        }
                    }
                }
                Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (!weatherPoller.running) weatherPoller.running = true } }

                Rectangle { anchors.fill: parent; color: root.base }

                property string activeWallCache: ""
                Process {
                    running: true
                    command: ["bash", "-c", "cat ~/.cache/mshell/wall_cache.txt 2>/dev/null || echo ''"]
                    stdout: StdioCollector { onStreamFinished: screenRoot.activeWallCache = text.trim() }
                }

                Image {
                    id: bgWallpaper
                    anchors.fill: parent
                    source: screenRoot.activeWallCache ? "file://" + screenRoot.activeWallCache : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                    cache: false
                }
                MultiEffect {
                    source: bgWallpaper
                    anchors.fill: bgWallpaper
                    blurEnabled: true
                    blurMax: 64
                    blur: 1.0
                }
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: 0.25
                }

                Item {
                    anchors.fill: parent
                    Rectangle {
                        width: parent.width * 0.8; height: width; radius: width / 2
                        x: (parent.width / 2 - width / 2) + Math.cos(screenRoot.globalOrbitAngle * 2) * 200
                        y: (parent.height / 2 - height / 2) + Math.sin(screenRoot.globalOrbitAngle * 2) * 150
                        scale: 1.0 + Math.sin(screenRoot.globalOrbitAngle * 6) * 0.05
                        opacity: screenRoot.inputActive ? 0.04 : 0.08
                        color: root.mauve
                    }
                    Rectangle {
                        width: parent.width * 0.9; height: width; radius: width / 2
                        x: (parent.width / 2 - width / 2) + Math.sin(screenRoot.globalOrbitAngle * 1.5) * -200
                        y: (parent.height / 2 - height / 2) + Math.cos(screenRoot.globalOrbitAngle * 1.5) * -150
                        scale: 1.0 + Math.cos(screenRoot.globalOrbitAngle * 5) * 0.05
                        opacity: screenRoot.inputActive ? 0.03 : 0.06
                        color: root.blue
                    }
                    Item {
                        anchors.fill: parent
                        opacity: screenRoot.introState
                        scale: 1.1 - (0.1 * screenRoot.introState)
                        Repeater {
                            model: 4
                            Rectangle {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -40
                                width: 400 + (index * 220)
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: lockUI.failed ? root.red : root.text
                                border.width: 1
                                opacity: lockUI.failed ? (0.1 - (index * 0.02)) : (screenRoot.inputActive ? (0.02 - (index * 0.005)) : (0.04 - (index * 0.01)))
                            }
                        }
                    }
                }

                // MAIN CONTENT LAYER (Clock & Auth)
                MouseArea {
                    anchors.fill: parent
                    enabled: !screenRoot.isPlayingIntro
                    onClicked: {
                        screenRoot.forceActiveFocus(); 
                    }
                }

                Item {
                    anchors.fill: parent
                    opacity: screenRoot.introState
                    transform: Translate { y: 30 * (1.0 - screenRoot.introState) }

                    // VERTICAL CLOCK
                    Item {
                        anchors.fill: parent
                        
                        property string clockHours: "00"
                        property string clockMinutes: "00"
                        property string clockSeconds: "00"

                        Text {
                            id: dateText
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 80
                            font.family: "JetBrains Mono"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: root.text
                        }

                        Text {
                            text: parent.clockHours
                            font.family: "JetBrains Mono"
                            font.pixelSize: 250
                            font.weight: Font.ExtraBold
                            color: root.text
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 120
                        }

                        Text {
                            text: parent.clockMinutes
                            font.family: "JetBrains Mono"
                            font.pixelSize: 250
                            font.weight: Font.ExtraBold
                            color: root.subtext0
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 400
                        }

                        Text {
                            text: parent.clockSeconds
                            font.family: "JetBrains Mono"
                            font.pixelSize: 45
                            font.weight: Font.ExtraBold
                            color: root.mauve
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 400
                        }

                        Timer {
                            interval: 500; running: true; repeat: true; triggeredOnStart: true
                            onTriggered: {
                                let d = new Date();
                                parent.clockHours = Qt.formatDateTime(d, "HH");
                                parent.clockMinutes = Qt.formatDateTime(d, "mm");
                                parent.clockSeconds = Qt.formatDateTime(d, "ss");
                                dateText.text = Qt.formatDateTime(d, "dddd, d MMMM");
                            }
                        }
                    }

                    // AUTHENTICATION MODULE
                    ColumnLayout {
                        id: authModule
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 200
                        spacing: 24

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8
                            Text {
                                text: ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 24
                                font.weight: Font.Bold
                                color: root.text
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: screenRoot.currentUser
                                font.family: "JetBrains Mono"
                                font.pixelSize: 24
                                font.weight: Font.Bold
                                color: root.text
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        // Password input pill
                        Rectangle {
                            id: pinPill
                            Layout.alignment: Qt.AlignHCenter
                            width: 300
                            height: 60
                            radius: 30
                            clip: true
                            color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.9)
                            border.width: 2
                            
                            border.color: {
                                if (lockUI.failed) return root.red;
                                if (lockUI.authenticating) return root.green;
                                if (lockUI.passwordBuffer.length > 0) return root.mauve;
                                return Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.3); // Dimmer when empty
                            }
                            Behavior on border.color {
                                ColorAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                            
                            Connections {
                                target: lockUI
                                function onFailedChanged() { 
                                    if (lockUI.failed) {
                                        lockUI.passwordBuffer = "";
                                        screenRoot.forceActiveFocus();
                                    }
                                }
                            }

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: 24
                                anchors.rightMargin: 24
                                clip: true
                                
                                Row {
                                    id: dotRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    
                                    property int activeWidth: lockUI.passwordBuffer.length > 0 
                                        ? (lockUI.passwordBuffer.length * 12) + ((lockUI.passwordBuffer.length - 1) * 8) 
                                        : 0
                                    
                                    x: activeWidth <= parent.width 
                                        ? (parent.width / 2 - activeWidth / 2) 
                                        : (parent.width - activeWidth)
                                    
                                    Behavior on x { 
                                        NumberAnimation { duration: 150; easing.type: Easing.OutSine } 
                                    }
                                    
                                    Repeater {
                                        model: 64
                                        Rectangle {
                                            width: 12
                                            height: 12
                                            radius: 6
                                            color: root.mauve
                                            
                                            property bool isActive: index < lockUI.passwordBuffer.length
                                            opacity: isActive ? 1.0 : 0.0
                                            
                                            Behavior on opacity {
                                                NumberAnimation { duration: 150; easing.type: Easing.InOutSine }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // BOTTOM GRADIENT
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 180
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.55) }
                    }
                }

                // BOTTOM SYSTEM INFO PILLS
                RowLayout {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    opacity: screenRoot.introState
                    transform: Translate { y: 20 * (1.0 - screenRoot.introState) }

                    // Battery pill
                    Rectangle {
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: batLayoutRow.implicitWidth + 32
                        radius: 22
                        color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.4)
                        border.color: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.08)
                        border.width: 1
                        RowLayout {
                            id: batLayoutRow; anchors.centerIn: parent; spacing: 8
                            property color dynamicBatColor: {
                                if (screenRoot.batStatus === "Charging") return root.green;
                                let pct = parseInt(screenRoot.batPct);
                                if (pct <= 20) return root.red;
                                return root.text;
                            }
                            Text { text: screenRoot.batStatus === "Charging" ? "󰂄" : (parseInt(screenRoot.batPct) <= 20 ? "󰂃" : "󰁹"); font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: batLayoutRow.dynamicBatColor }
                            Text { text: screenRoot.batPct + "%"; font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black; color: batLayoutRow.dynamicBatColor }
                        }
                    }

                    // Weather pill
                    Rectangle {
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: weatherRow.implicitWidth + 32
                        radius: 22
                        visible: screenRoot.weatherTemp !== "--°C"
                        color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.4)
                        border.color: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.08)
                        border.width: 1
                        RowLayout {
                            id: weatherRow; anchors.centerIn: parent; spacing: 8
                            Text { text: screenRoot.weatherIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: root.subtext0 }
                            Text { text: screenRoot.weatherTemp; font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black; color: root.text }
                        }
                    }
                }

                // INTRO ANIMATION OVERLAY
                Item {
                    id: introOverlay
                    anchors.fill: parent
                    z: 999
                    visible: screenRoot.isPlayingIntro || opacity > 0
                    Rectangle {
                        id: ring3
                        width: 360; height: 360; radius: 180
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.mauve
                        border.width: 1
                        scale: 0.5; opacity: 0.0
                    }
                    Rectangle {
                        id: ring2
                        width: 300; height: 300; radius: 150
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.text
                        border.width: 1
                        scale: 0.8; opacity: 0.0
                    }
                    Rectangle {
                        id: ring1
                        width: 240; height: 240; radius: 120
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.text
                        border.width: 2
                        scale: 0.8; opacity: 0.0
                    }
                    Item {
                        id: introLockOrb
                        width: 170; height: 170
                        anchors.centerIn: parent
                        scale: 0.0; opacity: 0.0
                        Rectangle {
                            anchors.fill: parent; radius: 85
                            color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.9)
                            border.color: root.text; border.width: 2
                        }
                        Text {
                            id: introIconUnlocked
                            anchors.centerIn: parent
                            text: "󰌿"; font.family: "Iosevka Nerd Font"; font.pixelSize: 64
                            color: root.text; opacity: 1.0; scale: 1.0
                        }
                        Text {
                            id: introIconLocked
                            anchors.centerIn: parent
                            text: "󰌾"; font.family: "Iosevka Nerd Font"; font.pixelSize: 64
                            color: root.text; opacity: 0.0; scale: 1.6
                        }
                    }
                    SequentialAnimation {
                        id: introSequence
                        ParallelAnimation {
                            NumberAnimation { target: introLockOrb; property: "scale"; from: 0.0; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
                            NumberAnimation { target: introLockOrb; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring1; property: "scale"; from: 0.8; to: 1.25; duration: 250; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring1; property: "opacity"; from: 0.6; to: 0.0; duration: 250; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring2; property: "scale"; from: 0.8; to: 1.4; duration: 300; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring2; property: "opacity"; from: 0.4; to: 0.0; duration: 300; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring3; property: "scale"; from: 0.5; to: 1.5; duration: 350; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring3; property: "opacity"; from: 0.3; to: 0.0; duration: 350; easing.type: Easing.OutCubic }
                            SequentialAnimation {
                                PauseAnimation { duration: 300 }
                                ParallelAnimation {
                                    NumberAnimation { target: introIconUnlocked; property: "scale"; from: 1.0; to: 0.5; duration: 200; easing.type: Easing.InCubic }
                                    NumberAnimation { target: introIconUnlocked; property: "opacity"; from: 1.0; to: 0.0; duration: 150 } // Increased for smooth crossfade
                                    NumberAnimation { target: introIconLocked; property: "scale"; from: 1.6; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                                    NumberAnimation { target: introIconLocked; property: "opacity"; from: 0.0; to: 1.0; duration: 150 } // Increased for smooth crossfade
                                    SequentialAnimation {
                                        NumberAnimation { target: introLockOrb; property: "anchors.verticalCenterOffset"; from: 0; to: 3; duration: 40; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: introLockOrb; property: "anchors.verticalCenterOffset"; from: 3; to: 0; duration: 120; easing.type: Easing.OutBack }
                                    }
                                }
                            }
                        }
                        PauseAnimation { duration: 50 }
                        SequentialAnimation {
                            ParallelAnimation {
                                NumberAnimation { target: introLockOrb; property: "scale"; to: 1.8; duration: 100; easing.type: Easing.InCubic }
                                NumberAnimation { target: introOverlay; property: "opacity"; to: 0.0; duration: 100; easing.type: Easing.InCubic }
                            }
                            NumberAnimation { target: screenRoot; property: "introState"; from: 0.0; to: 1.0; duration: 100; easing.type: Easing.OutCubic }
                        }
                        PropertyAction { target: screenRoot; property: "isPlayingIntro"; value: false }
                        ScriptAction { 
                            script: { 
                                lockUI.passwordBuffer = ""; 
                                screenRoot.forceActiveFocus(); 
                            } 
                        }
                    }
                }
            }
        }
    }
}