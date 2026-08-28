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
import Quickshell.Services.Mpris
import "."

Scope {
    id: root

    property string lockSnapshotDir: Quickshell.env("XDG_RUNTIME_DIR") + "/mshell-lock-snapshots"
    property bool capsLockActive: false
    property bool initialLockDone: false

    function getGreetingParts(): var {
        let h = new Date().getHours()
        if (h >= 5 && h < 12) return { prefix: "Good", main: "Morning" }
        if (h >= 12 && h < 17) return { prefix: "Good", main: "Afternoon" }
        if (h >= 17 && h < 22) return { prefix: "Good", main: "Evening" }
        if (h >= 22 || h < 2) return { prefix: "Good", main: "Night" }
        return { prefix: "Sweet", main: "Dreams" }
    }

    Process {
        id: lockSnapshotProc
        property bool pendingLock: false
        onRunningChanged: {
            if (!running && pendingLock) {
                pendingLock = false
                rootLock.locked = true
            }
        }
    }

    function requestSessionLock() {
        if (rootLock.locked) return
        lockSnapshotProc.pendingLock = true
        lockSnapshotProc.command = [
            "bash", "-c",
            "mkdir -p '" + root.lockSnapshotDir + "' && rm -f '" + root.lockSnapshotDir + "'/*.png && " +
            "for o in $(hyprctl monitors -j | jq -r '.[].name'); do grim -o \"$o\" \"" + root.lockSnapshotDir + "/$o.png\"; done"
        ]
        lockSnapshotProc.running = true
    }

    IpcHandler {
        target: "lock"
        function triggerSessionLock(): void {
            root.requestSessionLock()
        }
    }

    GlobalShortcut {
        name: "triggerSessionLock"
        onPressed: root.requestSessionLock()
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
    property string activeWallCache: ""
    property string batPct: "100"
    property string batStatus: "AC"
    property string currentUser: "User"
    property string faceIconPath: ""
    property string kbLayout: "US"
    property string weatherIcon: ""
    property string weatherTemp: "--°C"

    FileView {
        id: wallCacheFile
        path: Quickshell.env("HOME") + "/.cache/mshell/wall_cache.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.activeWallCache = text().trim()
    }

    Process {
        id: userPoller
        command: ["bash", "-c", "USER_VAR=$(whoami); ICON_PATH=\"\"; if [ -f ~/.face.icon ]; then ICON_PATH=$(readlink -f ~/.face.icon); elif [ -f ~/.face ]; then ICON_PATH=$(readlink -f ~/.face); fi; echo -n \"$USER_VAR|$ICON_PATH\""]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|");
                if (parts.length > 0 && parts[0] !== "") root.currentUser = parts[0];
                if (parts.length > 1 && parts[1].trim() !== "") {
                    let path = parts[1].trim();
                    root.faceIconPath = path.startsWith("file://") ? path : "file://" + path;
                }
            }
        }
        Component.onCompleted: running = true
    }

    // Keyboard layout & Caps Lock Poller
    Process {
        id: kbPoller
        command: ["bash", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | \"\\(.active_keymap // \"US\")|\\(.capsLock // false)\"' | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|");
                if (parts.length > 0 && parts[0] !== "" && parts[0] !== "null") {
                    root.kbLayout = parts[0].substring(0, 2).toUpperCase();
                }
                if (parts.length > 1) {
                    root.capsLockActive = (parts[1].trim() === "true");
                }
            }
        }
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (!kbPoller.running) kbPoller.running = true } }

    Process {
        id: batPoller
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo '100'; cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1 || echo 'AC'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 2) {
                    root.batPct = lines[0] || "100";
                    root.batStatus = lines[1] || "Unknown";
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
                        root.weatherIcon = root.weatherIconCode(data.today.icon)
                        root.weatherTemp = Math.round(data.today.temp) + "°C"
                    }
                } catch(e) {}
            }
        }
    }
    Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (!weatherPoller.running) weatherPoller.running = true } }

    WlSessionLock {
        id: rootLock
        locked: false

        onLockedChanged: {
            if (!locked) {
                root.initialLockDone = false;
            }
        }

        WlSessionLockSurface {
            id: surface

            Item {
                id: screenRoot
                anchors.fill: parent
                property real introState: 1.0 
                property bool powerMenuOpen: false
                property bool inputActive: false
                property bool isPlayingIntro: false 

                // Automatic keyboard focus recovery on wake from suspend
                onActiveFocusChanged: {
                    if (!activeFocus && rootLock.locked) {
                        focusHammer.attempts = 0;
                        focusHammer.running = true;
                    }
                }

                Timer {
                    id: focusHammer
                    interval: 60
                    repeat: true
                    property int attempts: 0
                    onTriggered: {
                        screenRoot.forceActiveFocus();
                        attempts++;
                        if (screenRoot.activeFocus || attempts > 25) {
                            running = false;
                        }
                    }
                }

                // Frame pump to force Wayland buffer damage on wake (bypasses Hyprland VFR sleep)
                Canvas {
                    id: framePump
                    width: 1
                    height: 1
                    opacity: 0.01
                    anchors.top: parent.top
                    anchors.left: parent.left
                    
                    Timer {
                        interval: 200
                        running: rootLock.locked
                        repeat: true
                        onTriggered: framePump.requestPaint()
                    }

                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.clearRect(0, 0, 1, 1);
                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.01);
                        ctx.fillRect(0, 0, 1, 1);
                    }
                }

                // Heartbeat to guarantee focus when session is locked
                Timer {
                    interval: 1000
                    running: rootLock.locked
                    repeat: true
                    onTriggered: {
                        if (!screenRoot.activeFocus) {
                            screenRoot.forceActiveFocus();
                        }
                    }
                }

                Component.onCompleted: {
                    lockUI.passwordBuffer = "";
                    
                    if (!root.initialLockDone) {
                        root.initialLockDone = true;
                        introSequence.start();
                    } else {
                        // Wake from sleep / monitor reconnect: skip snapshot and show lock screen immediately
                        screenRoot.introState = 1.0;
                        freezeFrame.opacity = 0.0;
                        freezeFrame.source = "";
                    }

                    focusHammer.attempts = 0;
                    focusHammer.running = true;
                }

                focus: true 
                Keys.onPressed: (event) => {
                    if (screenRoot.isPlayingIntro || lockUI.authenticating) return;

                    inputActive = true; 

                    if (event.key === Qt.Key_CapsLock) {
                        root.capsLockActive = !root.capsLockActive;
                        if (!kbPoller.running) kbPoller.running = true;
                    } else if (event.key === Qt.Key_Escape) {
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

                Rectangle { anchors.fill: parent; color: root.base }

                Image {
                    id: freezeFrame
                    anchors.fill: parent
                    z: 500
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: false
                    source: (surface.screen && surface.screen.name) ? ("file://" + root.lockSnapshotDir + "/" + surface.screen.name + ".png") : ""
                    visible: opacity > 0
                }

                Image {
                    id: bgWallpaper
                    anchors.fill: parent
                    source: root.activeWallCache ? "file://" + root.activeWallCache : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                    cache: true
                    sourceSize.width: Screen.width
                    sourceSize.height: Screen.height
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

                // Clock and Auth
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.BlankCursor
                    onClicked: screenRoot.forceActiveFocus()
                }

                property var activePlayer: null
                property string currentTrackTitle: ""
                property string currentTrackArtist: ""
                property string persistentArtUrl: ""

                Item {
                    anchors.fill: parent
                    opacity: screenRoot.introState
                    transform: Translate { y: 30 * (1.0 - screenRoot.introState) }

                    // Clock
                    Item {
                        anchors.fill: parent
                        
                        property string clockHours: "00"
                        property string clockMinutes: "00"
                        property string clockSeconds: "00"

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

                        Text {
                            id: dateText
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 60
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: root.text
                        }

                        Text {
                            id: hourText
                            text: parent.clockHours
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 250
                            font.weight: Font.Bold
                            color: root.text
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: dateText.bottom
                            anchors.topMargin: 0
                            z: 1
                        }

                        Item {
                            id: minSecContainer
                            anchors.left: hourText.left
                            anchors.top: hourText.bottom
                            anchors.topMargin: -65
                            
                            width: minText.width + secText.width + 12
                            height: minText.height
                            z: 2

                            Text {
                                id: minText
                                text: minSecContainer.parent.clockMinutes
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 250
                                font.weight: Font.Bold
                                color: root.subtext0
                                anchors.left: parent.left
                                anchors.top: parent.top
                            }

                            Text {
                                id: secText
                                text: minSecContainer.parent.clockSeconds
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 60
                                font.weight: Font.Bold
                                color: root.mauve
                                
                                anchors.left: minText.right
                                anchors.leftMargin: 12
                                anchors.baseline: minText.baseline 
                            }
                        }
                    }

                    // MPRIS Media Card
                    Timer {
                        interval: 1000; running: true; repeat: true; triggeredOnStart: true
                        onTriggered: {
                            let players = Mpris.players.values
                            if (!players || players.length === 0) {
                                screenRoot.activePlayer = null
                                return
                            }
                            
                            let currentlyPlaying = null
                            for (let i = 0; i < players.length; i++) {
                                let state = players[i].playbackState
                                if (state === 1 || state === "Playing") { 
                                    currentlyPlaying = players[i]
                                    break
                                }
                            }
                            
                            screenRoot.activePlayer = currentlyPlaying ? currentlyPlaying : players[0]
                            screenRoot.currentTrackTitle = screenRoot.activePlayer.trackTitle || "Unknown Track"
                            screenRoot.currentTrackArtist = screenRoot.activePlayer.trackArtist || "Unknown Artist"
                            
                            let newArt = screenRoot.activePlayer.trackArtUrl
                            if (newArt && newArt !== "") {
                                screenRoot.persistentArtUrl = newArt
                            }
                        }
                    }

                    Rectangle {
                        id: lockMediaPanel
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: authModule.top
                        anchors.bottomMargin: 36
                        
                        width: 360
                        height: 78
                        radius: 20
                        
                        color: Qt.rgba(root.crust.r, root.crust.g, root.crust.b, 0.55)
                        border.width: 1
                        border.color: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.12)
                        
                        opacity: (screenRoot.activePlayer ? 1.0 : 0.0) * screenRoot.introState
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                        transform: Translate { y: 20 * (1.0 - screenRoot.introState) }

                        Rectangle {
                            id: lockMediaMask
                            anchors.fill: parent
                            radius: 20
                            visible: false
                            layer.enabled: true
                        }

                        Item {
                            id: lockAlbumGlowContainer
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            
                            Image {
                                x: 12; y: 12; width: 54; height: 54
                                source: screenRoot.persistentArtUrl
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                asynchronous: true
                                sourceSize.width: 128
                                sourceSize.height: 128
                            }
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: lockAlbumGlowContainer
                            maskEnabled: true
                            maskSource: lockMediaMask
                            blurEnabled: true
                            blurMax: 84
                            blur: 1.0
                            saturation: 2.5
                            opacity: lockAlbumArt.status === Image.Ready ? 0.5 : 0
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14

                            // Album Artwork
                            Item {
                                width: 54; height: 54
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: Theme.surfaceHover
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰝚"
                                        color: root.subtext0
                                        font.pixelSize: 22
                                    }
                                }

                                Image {
                                    id: lockAlbumArt
                                    anchors.fill: parent
                                    source: screenRoot.persistentArtUrl
                                    fillMode: Image.PreserveAspectCrop
                                    layer.enabled: true
                                    visible: false
                                    cache: false
                                    asynchronous: true
                                    sourceSize.width: 128
                                    sourceSize.height: 128
                                }

                                Rectangle {
                                    id: lockArtMask
                                    anchors.fill: parent
                                    radius: 14
                                    layer.enabled: true
                                    visible: false
                                }

                                MultiEffect {
                                    anchors.fill: parent
                                    source: lockAlbumArt
                                    maskEnabled: true
                                    maskSource: lockArtMask
                                    opacity: lockAlbumArt.status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }

                            // Track Metadata
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 54 - 14
                                spacing: 4

                                Text {
                                    text: screenRoot.currentTrackTitle
                                    color: root.text
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    text: screenRoot.currentTrackArtist
                                    color: root.subtext0
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                        }
                    }

                    // Authentication Module
                    ColumnLayout {
                        id: authModule
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 140
                        spacing: 20

                        // User profile info
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8
                            Text {
                                text: ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 22
                                font.weight: Font.Bold
                                color: root.mauve
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: root.currentUser
                                font.family: "JetBrains Mono"
                                font.pixelSize: 22
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
                            height: 56
                            radius: 28
                            clip: false
                            color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.9)
                            border.width: 2
                            
                            border.color: {
                                if (lockUI.failed) return root.red;
                                if (lockUI.authenticating) return root.green;
                                if (lockUI.passwordBuffer.length > 0) return root.mauve;
                                return Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.3);
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

                            // Caps Lock Warning Pill
                            Rectangle {
                                id: capsWarning
                                anchors.top: parent.bottom
                                anchors.topMargin: 12
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: 28
                                width: capsRow.implicitWidth + 24
                                radius: 14
                                color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.15)
                                border.width: 1
                                border.color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.4)

                                opacity: root.capsLockActive ? 1.0 : 0.0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                                Row {
                                    id: capsRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰪛"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        color: root.peach
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Caps Lock is on"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: root.peach
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }

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

                // Greeting Card (Bottom-Left)
                Rectangle {
                    id: greetingCard
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40
                    anchors.left: parent.left
                    anchors.leftMargin: 40

                    property var greeting: root.getGreetingParts()

                    width: greetingLayout.implicitWidth + 64
                    height: greetingLayout.implicitHeight + 44
                    radius: 28

                    color: Qt.rgba(root.crust.r, root.crust.g, root.crust.b, 0.65)
                    border.width: 1.5
                    border.color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.25)
                    clip: true

                    opacity: screenRoot.introState
                    transform: Translate { y: 25 * (1.0 - screenRoot.introState) }

                    Rectangle {
                        anchors.fill: parent
                        radius: 28
                        gradient: Gradient {
                            orientation: Gradient.TopLeftToBottomRight
                            GradientStop { position: 0.0; color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.16) }
                            GradientStop { position: 0.6; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.08) }
                        }
                    }

                    Column {
                        id: greetingLayout
                        anchors.centerIn: parent
                        spacing: -7

                        Text {
                            text: greetingCard.greeting.prefix
                            font.family: "Product Sans, Google Sans, sans-serif"
                            font.pixelSize: 42
                            font.weight: Font.Black
                            color: root.text
                        }

                        Text {
                            text: greetingCard.greeting.main
                            leftPadding: 36
                            font.family: "Product Sans, Google Sans, sans-serif"
                            font.pixelSize: 46
                            font.weight: Font.Black
                            color: root.mauve
                        }
                    }
                }

                // Bottom Status Pills
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
                                if (root.batStatus === "Charging") return root.green;
                                let pct = parseInt(root.batPct);
                                if (pct <= 20) return root.red;
                                return root.text;
                            }
                            Text { text: root.batStatus === "Charging" ? "󰂄" : (parseInt(root.batPct) <= 20 ? "󰂃" : "󰁹"); font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: batLayoutRow.dynamicBatColor }
                            Text { text: root.batPct + "%"; font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black; color: batLayoutRow.dynamicBatColor }
                        }
                    }

                    // Weather pill
                    Rectangle {
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: weatherRow.implicitWidth + 32
                        radius: 22
                        visible: root.weatherTemp !== "--°C"
                        color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.4)
                        border.color: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.08)
                        border.width: 1
                        RowLayout {
                            id: weatherRow; anchors.centerIn: parent; spacing: 8
                            Text { text: root.weatherIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: root.subtext0 }
                            Text { text: root.weatherTemp; font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black; color: root.text }
                        }
                    }
                }

                // Animation Sequencer
                SequentialAnimation {
                    id: introSequence
                    ScriptAction {
                        script: {
                            screenRoot.isPlayingIntro = true;
                            screenRoot.introState = 0.0;
                            freezeFrame.opacity = 1.0;
                        }
                    }
                    PauseAnimation { duration: 20 }
                    ParallelAnimation {
                        NumberAnimation { target: freezeFrame; property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.OutCubic }
                        NumberAnimation { target: screenRoot; property: "introState"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
                    }
                    PropertyAction { target: screenRoot; property: "isPlayingIntro"; value: false }
                    ScriptAction {
                        script: {
                            freezeFrame.opacity = 0.0;
                            freezeFrame.source = "";
                            lockUI.passwordBuffer = "";
                            screenRoot.forceActiveFocus();
                            focusHammer.attempts = 0;
                            focusHammer.running = true;
                        }
                    }
                }
            }
        }
    }
}