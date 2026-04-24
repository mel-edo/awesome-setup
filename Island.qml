import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import "."

Scope {
    IpcHandler {
        target: "island"
        function showOsd(value: string, type: string) {
            islandWindow.showOsd(Number(value), type)
        }
    }

    WlrLayershell {
        id: islandWindow
        anchors.top: true
        anchors.left: true
        anchors.right: true
        exclusiveZone: -1
        layer: WlrLayer.Top
        implicitHeight: 500
        implicitWidth: Screen.width
        color: "transparent"
        mask: Region { item: mainPill }
        property var cavaValues: []
        property bool cavaActive: false
        property bool showClock: true
        property string islandState: "idle"
        property bool isHovered: false
        property bool postHubCava: false
        property var weatherToday: null
        property var weatherForecast: []
        property var activePlayer: null
        property string currentTrackTitle: ""
        property int osdValue: 50
        property string osdType: "volume"
        property bool isOsdIdle: false
        property bool btInitialized: false
        property var btDeviceState: ({})
        property string latestBtDevice: ""
        property string latestBtBattery: ""
        property Notification activeNotification
        property string notifAppName: "System"
        property string notifSummary: ""
        property string notifBody: ""
        property string notifIcon: ""
        property string notifImage: ""

        function closeToIdle() {
            islandState = "idle"
            hubDelayTimer.stop()
            hubStayTimer.stop()
            idleStayTimer.stop()
            notificationTimer.stop()
            osdTimeoutTimer.stop()
            islandWindow.showClock = true 
            if (islandWindow.cavaActive) {
                alternateTimer.restart()
            } else {
                alternateTimer.stop()
            }
        }

        function showBtPopup() {
            if (islandWindow.islandState === "osd" || 
                islandWindow.islandState === "calendar" || 
                islandWindow.islandState === "notification" || 
                islandWindow.islandState === "notifications") return
                
            islandWindow.islandState = "bluetooth"
            islandWindow.postHubCava = false
            islandWindow.showClock = true
            alternateTimer.stop()
            hubStayTimer.restart()
        }

        function weatherIcon(code) {
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

        function showOsd(value, type) {
            osdValue = value
            osdType = type
            islandWindow.islandState = "osd"
            islandWindow.isOsdIdle = false
            osdIdleTimer.restart()
            osdTimeoutTimer.restart()
            islandWindow.showClock = true
            if (islandWindow.cavaActive) {
                alternateTimer.restart()
            }
        }

        function showMediaPopup() {
            if (islandWindow.islandState === "osd" || 
                islandWindow.islandState === "calendar" || 
                islandWindow.islandState === "notification" || 
                islandWindow.islandState === "notifications") return
            islandWindow.islandState = "media"
            islandWindow.postHubCava = true
            islandWindow.showClock = false
            alternateTimer.stop()
            hubStayTimer.restart()
        }

        Timer {
            id: alternateTimer
            interval: islandWindow.showClock ? 11000 : 6000
            repeat: true
            onTriggered: {
                islandWindow.showClock = !islandWindow.showClock
                interval = islandWindow.showClock ? 11000 : 6000
                alternateTimer.restart()
            }
        }

        ListModel {
            id: notifQueue
        }

        NotificationServer {
            id: notifServer
            onNotification: notification => {
                hubDelayTimer.stop()
                hubStayTimer.stop()
                idleStayTimer.stop()
                osdTimeoutTimer.stop()
                if (islandWindow.islandState !== "notification") {
                    notifQueue.clear() 
                }
                notifQueue.insert(0, {
                    nApp: notification.appName || "System",
                    nSum: notification.summary || "",
                    nBod: notification.body || "",
                    nIco: notification.appIcon || "",
                    nImg: notification.image || ""
                })
                notifRenderTimer.restart()
            }
        }

        Timer {
            id: notifRenderTimer
            interval: 30 
            onTriggered: {
                islandWindow.islandState = "notification"
                notificationTimer.restart()
            }
        }

        Timer {
            id: notificationTimer
            interval: 3000 
            onTriggered: {
                if (islandWindow.islandState === "notification") {
                    islandWindow.closeToIdle()
                }
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                let players = Mpris.players.values
                if (!players || players.length === 0) {
                    islandWindow.activePlayer = null
                    islandWindow.currentTrackTitle = ""
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
                islandWindow.activePlayer = currentlyPlaying ? currentlyPlaying : players[0]
                let newTitle = islandWindow.activePlayer ? (islandWindow.activePlayer.trackTitle || "") : ""
                if (islandWindow.currentTrackTitle !== "" && newTitle !== "" && islandWindow.currentTrackTitle !== newTitle) {
                    islandWindow.showMediaPopup()
                }
                islandWindow.currentTrackTitle = newTitle
            }
        }

        Timer {
            id: silenceTimer
            interval: 2500
            onTriggered: {
                islandWindow.cavaActive = false
                islandWindow.showClock = true
                islandWindow.postHubCava = false
                alternateTimer.stop()
            }
        }

        Timer {
            id: hubStayTimer
            interval: 3000
            onTriggered: {
                islandWindow.islandState = "idle" 
                if (islandWindow.cavaActive && islandWindow.postHubCava) {
                    idleStayTimer.start() 
                } else {
                    islandWindow.closeToIdle()
                }
            }
        }

        Timer {
            id: idleStayTimer
            interval: 3000 
            onTriggered: {
                islandWindow.postHubCava = false
                islandWindow.showClock = true 
                if (islandWindow.cavaActive) {
                    alternateTimer.restart() 
                }
                islandWindow.closeToIdle()
            }
        }

        Timer {
            id: weatherDelayTimer
            interval: 300
            onTriggered: weatherProcess.running = true
        }

        Timer {
            id: hubDelayTimer
            interval: 80
            onTriggered: islandWindow.islandState = "hub"
        }

        Timer {
            id: osdTimeoutTimer
            interval: 2500 
            onTriggered: {
                islandWindow.closeToIdle()
            }
        }

        Timer {
            id: osdIdleTimer
            interval: 800
            onTriggered: islandWindow.isOsdIdle = true
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: btProcess.running = true
        }

        Process {
            id: btProcess
            command: ["bash", "-c", "bluetoothctl devices Connected | while read -r _ mac name; do bat=$(bluetoothctl info \"$mac\" | grep 'Battery Percentage:' | awk -F '[()]' '{print $2}'); [ -z \"$bat\" ] && bat=\"--\"; echo \"$mac|$name|$bat\"; done"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let lines = text.trim().split("\n").filter(x => x !== "")
                    let currentMacs = []
                    let now = Date.now()
                    let isMacPattern = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/i

                    for (let i = 0; i < lines.length; i++) {
                        let parts = lines[i].split("|")
                        if (parts.length < 3) continue;
                        
                        let mac = parts[0].trim()
                        let name = parts[1].trim()
                        let bat = parts[2].trim()
                        
                        currentMacs.push(mac)

                        let altMac = mac.replace(/:/g, "-")
                        if (isMacPattern.test(name) || name === mac || name === altMac) continue;

                        if (!islandWindow.btDeviceState[mac]) {
                            islandWindow.btDeviceState[mac] = { firstSeen: now, shown: false }
                        }

                        let device = islandWindow.btDeviceState[mac]

                        if (!islandWindow.btInitialized) {
                            device.shown = true
                            continue;
                        }

                        if (!device.shown) {
                            let hasBattery = bat !== "--" && bat !== ""
                            let waitedLongEnough = (now - device.firstSeen) > 3000

                            if (hasBattery || waitedLongEnough) {
                                islandWindow.latestBtDevice = name
                                islandWindow.latestBtBattery = bat
                                islandWindow.showBtPopup()
                                device.shown = true
                            }
                        }
                    }
                    let keys = Object.keys(islandWindow.btDeviceState)
                    for (let k = 0; k < keys.length; k++) {
                        if (!currentMacs.includes(keys[k])) {
                            delete islandWindow.btDeviceState[keys[k]]
                        }
                    }

                    if (!islandWindow.btInitialized) {
                        islandWindow.btInitialized = true
                    }
                }
            }
        }

        Process {
            id: cavaProcess
            command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/mshell.conf"]
            running: true
            stdout: SplitParser {
                onRead: data => {
                    let bars = data.trim().split(";").filter(x => x !== "").map(Number)
                    if (bars.length > 0) {
                        islandWindow.cavaValues = bars
                        if (bars.some(v => v > 1)) {
                            if (!islandWindow.cavaActive) {
                                islandWindow.cavaActive = true
                                islandWindow.showClock = true 
                                if (islandWindow.islandState === "idle") {
                                    alternateTimer.restart()
                                }
                            }
                            silenceTimer.restart()
                        }
                    }
                }
            }
        }

        Process {
            id: weatherProcess
            command: [Quickshell.env("HOME") + "/.config/quickshell-new/mshell/scripts/calendar/weather.sh"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        let data = JSON.parse(text)
                        islandWindow.weatherToday = data.today
                        islandWindow.weatherForecast = data.forecast
                    } catch(e) {
                        console.log("[Weather] parse error:", e)
                    }
                }
            }
        }

        Rectangle {
            id: mainPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            
            // Main Width vals
            width: {
                if (islandWindow.islandState === "idle") return 180
                if (islandWindow.islandState === "osd") return 252
                if (islandWindow.islandState === "media" || islandWindow.islandState === "hub" || islandWindow.islandState === "bluetooth") return 350
                if (islandWindow.islandState === "notification" || islandWindow.islandState === "notifications") return 410
                if (islandWindow.islandState === "calendar") return 660
                return 180
            }
            
            // Main Height vals
            height: {
                if (islandWindow.islandState === "idle") return 34
                if (islandWindow.islandState === "osd") return 52
                if (islandWindow.islandState === "media" || islandWindow.islandState === "hub" || islandWindow.islandState === "bluetooth") return 68
                if (islandWindow.islandState === "calendar") return 290
                if (islandWindow.islandState === "notification") {
                    if (notifQueue.count === 0) return 34
                    return notifContainer.height + 16
                }
                if (islandWindow.islandState === "notifications") {
                    if (notifQueue.count === 0) return 68 
                    return notifContainer.height + 16
                }
                return 34
            }
            
            radius: islandWindow.islandState === "calendar" ? 24 : height / 3
            topLeftRadius: 0
            topRightRadius: 0
            
            color: Theme.surface
            clip: true

            // The Liquid Spring Physics
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }

            HoverHandler {
                id: pillHover
                onHoveredChanged: {
                    if (islandWindow.islandState === "notification" || notifRenderTimer.running) {
                        return;
                    }
                    if (hovered) {
                        hubStayTimer.stop()
                        idleStayTimer.stop()
                        islandWindow.postHubCava = false
                        hubDelayTimer.start()
                    } else {
                        hubDelayTimer.stop()
                        
                        if (islandWindow.cavaActive) {
                            islandWindow.islandState = "media" 
                            islandWindow.postHubCava = true
                            islandWindow.showClock = false
                            alternateTimer.stop()
                            hubStayTimer.start()
                        } else {
                            islandWindow.closeToIdle()
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 8

                Item {
                    id: osdLayout
                    anchors.centerIn: parent
                    width: 220
                    height: 36 
                    
                    property bool isActiveOsd: islandWindow.islandState === "osd"
                    visible: isActiveOsd
                    opacity: isActiveOsd ? 1 : 0
                    Behavior on opacity { 
                        SequentialAnimation {
                            PauseAnimation { duration: osdLayout.isActiveOsd ? 150 : 0 }
                            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                        }
                    }

                    // 1. The Track Base
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.highlight
                    }

                    // 2. The Colored Fill
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        
                        // Physically locked to the head!
                        width: sliderHead.x + sliderHead.width 
                        radius: height / 2 
                        
                        color: islandWindow.osdValue > 100 ? Theme.danger : Theme.subtext
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // 3. The Moving Slider Head
                    Rectangle {
                        id: sliderHead
                        width: parent.height 
                        height: parent.height
                        radius: width / 2
                        color: Theme.text
                        
                        x: (Math.min(islandWindow.osdValue, 100) / 100) * (parent.width - width)
                        
                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (islandWindow.osdType === "volume") {
                                    if (islandWindow.osdValue <= 0) return "󰖁" 
                                    if (islandWindow.osdValue < 33) return "󰕿" 
                                    if (islandWindow.osdValue < 66) return "󰖀" 
                                    return "󰕾" 
                                } else {
                                    if (islandWindow.osdValue < 33) return "󰃞" 
                                    if (islandWindow.osdValue < 66) return "󰃟" 
                                    return "󰃠" 
                                }
                            }
                            color: Theme.background
                            font.pixelSize: 18
                            
                            opacity: islandWindow.isOsdIdle ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                        }

                        // PERCENTAGE (Fades IN when moving)
                        Text {
                            anchors.centerIn: parent
                            text: islandWindow.osdValue
                            color: Theme.background // Dark Text
                            font.pixelSize: 13
                            font.bold: true
                            
                            opacity: islandWindow.isOsdIdle ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                        }
                    }
                }

                // Incoming Notifications Stack
                Item {
                    id: notifContainer
                    width: 380
                    height: notifQueue.count === 0 ? 30 : Math.min(notifList.contentHeight, 160)
                    anchors.centerIn: parent

                    property bool isActiveNotif: islandWindow.islandState === "notification" || islandWindow.islandState === "notifications"
                    visible: isActiveNotif
                    opacity: isActiveNotif ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                notificationTimer.stop()
                            } else if (notifContainer.isActiveNotif) {
                                notificationTimer.restart()
                            }
                        }
                    }

                    Text {
                        id: emptyStateText
                        anchors.centerIn: parent
                        text: "No new notifications"
                        color: Theme.subtext
                        font.pixelSize: 14
                        font.bold: true
                        property bool showEmpty: notifQueue.count === 0 && islandWindow.islandState === "notifications"
                        
                        // Bind visibility to opacity so it fully hides when invisible
                        visible: opacity > 0
                        opacity: showEmpty ? 1 : 0
                        
                        Behavior on opacity { 
                            SequentialAnimation {
                                PauseAnimation { duration: emptyStateText.showEmpty ? 250 : 0 }
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    ListView {
                        id: notifList
                        anchors.fill: parent
                        model: notifQueue
                        spacing: 8
                        clip: true
                        interactive: true 
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: NotifCard {} 
                        remove: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; to: 0; duration: 250 }
                                NumberAnimation { property: "height"; to: 0; duration: 300; easing.type: Easing.OutQuad }
                            }
                        }
                        removeDisplaced: Transition {
                            NumberAnimation { property: "y"; duration: 400; easing.type: Easing.OutQuad }
                        }
                    }
                }

                // IDLE CLOCK
                Text {
                    id: clockText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    text: Qt.formatDateTime(new Date(), "HH:mm:ss • ddd, MMM dd")
                    color: Theme.text
                    font.pixelSize: 14
                    
                    property bool isActiveText: islandWindow.islandState === "idle" && 
                                                !islandWindow.postHubCava && 
                                                (!islandWindow.cavaActive || islandWindow.showClock)
                    
                    visible: isActiveText
                    opacity: isActiveText ? 1 : 0
                    
                    Behavior on opacity { 
                        SequentialAnimation {
                            PauseAnimation { duration: clockText.isActiveText ? 200 : 0 }
                            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                        }
                    }

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm:ss • ddd, MMM dd")
                    }
                }

                // IDLE CAVA
                Row {
                    id: cavaRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 24 
                    spacing: 4
                    
                    property bool isActiveCava: islandWindow.islandState === "idle" && 
                                                (islandWindow.postHubCava || (islandWindow.cavaActive && !islandWindow.showClock))
                    
                    visible: isActiveCava
                    opacity: isActiveCava ? 1 : 0
                    
                    Behavior on opacity { 
                        SequentialAnimation {
                            PauseAnimation { duration: cavaRow.isActiveCava ? 200 : 0 }
                            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                        }
                    }

                    Repeater {
                        model: islandWindow.cavaValues ? islandWindow.cavaValues.length : 0
                        Rectangle {
                            property real calcWidth: (cavaRow.width - (cavaRow.spacing * (islandWindow.cavaValues.length - 1))) / Math.max(1, islandWindow.cavaValues.length)
                            width: Math.max(2, calcWidth)
                            height: {
                                let val = islandWindow.cavaValues[index] || 0
                                let h = (val / 9) * cavaRow.height
                                return Math.max(3, Math.min(h, cavaRow.height)) 
                            }
                            anchors.bottom: parent.bottom
                            radius: width / 2
                            color: Theme.accent
                            Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutQuad } }
                        }
                    }
                }

                // HUB PANEL
                Row {
                    id: hubRow
                    anchors.centerIn: parent
                    spacing: 16
                    
                    property bool isActiveHub: islandWindow.islandState === "hub" && !islandWindow.postHubCava
                    visible: isActiveHub
                    opacity: isActiveHub ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    Repeater {
                        model: [
                            { icon: "󰃶", state: "calendar", accent: Theme.accent },
                            { icon: "󰂚", state: "notifications", accent: Theme.accentAlt },
                            { icon: "󰸉", state: "wallpaper", accent: Theme.border }
                        ]
                        Item {
                            required property var modelData
                            width: 44; height: 44
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: parent.modelData.accent
                                opacity: hubBtnHover.hovered ? 0.2 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.icon
                                font.pixelSize: 20
                                color: hubBtnHover.hovered ? parent.modelData.accent : Theme.text
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            HoverHandler { id: hubBtnHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: islandWindow.islandState = parent.modelData.state }
                        }
                    }
                }

                // MEDIA PANEL
                Item {
                    id: mediaPanel
                    width: 334
                    height: 52
                    anchors.centerIn: parent
                    
                    property bool isActiveMedia: islandWindow.islandState === "media"
                    visible: isActiveMedia
                    opacity: isActiveMedia ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.fill: parent
                        spacing: 12

                        // --- PERFECTLY ROUNDED ALBUM ART ---
                        Item {
                            width: 52; height: 52
                            
                            // 1. Fallback Background (Always rendered underneath!)
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: Theme.surfaceHover
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰝚"
                                    color: Theme.subtext
                                    font.pixelSize: 24
                                }
                            }

                            // 2. The Raw Square Image (Hidden from view, but active in memory)
                            Image {
                                id: albumArt
                                anchors.fill: parent
                                source: islandWindow.activePlayer && islandWindow.activePlayer.trackArtUrl ? islandWindow.activePlayer.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                
                                // The Trick: Forces it to load into the GPU even while invisible!
                                layer.enabled: true 
                                visible: false 
                            }

                            // 3. The Rounded Mask Shape (Hidden from view, but active in memory)
                            Rectangle {
                                id: artMask
                                width: 52; height: 52
                                radius: 12
                                
                                layer.enabled: true
                                visible: false
                            }

                            // 4. The Final Masked Output
                            MultiEffect {
                                anchors.fill: parent
                                source: albumArt
                                maskEnabled: true
                                maskSource: artMask
                                
                                // Only fades in the masked image when it finishes downloading!
                                opacity: albumArt.status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }
                        // Track Info
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 140 
                            Text { 
                                text: islandWindow.activePlayer ? (islandWindow.activePlayer.trackTitle || "Unknown Track") : "No Media"
                                color: Theme.text; font.pixelSize: 14; font.bold: true
                                elide: Text.ElideRight; width: parent.width 
                            }
                            Text { 
                                text: islandWindow.activePlayer ? (islandWindow.activePlayer.trackArtist || "Unknown Artist") : ""
                                color: Theme.subtext; font.pixelSize: 12
                                elide: Text.ElideRight; width: parent.width 
                            }
                        }

                        // --- FIXED: Grounded Cava Visualizer ---
                        Row {
                            width: 100 
                            height: 52 // MATCHES ALBUM ART HEIGHT!
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            
                            Repeater {
                                model: islandWindow.cavaValues ? islandWindow.cavaValues.length : 0
                                Rectangle {
                                    property real calcWidth: (parent.width - (parent.spacing * (islandWindow.cavaValues.length - 1))) / Math.max(1, islandWindow.cavaValues.length)
                                    width: Math.max(2, calcWidth)
                                    height: {
                                        let val = islandWindow.cavaValues[index] || 0
                                        let h = (val / 9) * (parent.height * 0.7) 
                                        return Math.max(3, Math.min(h, parent.height))
                                    }
                                    anchors.bottom: parent.bottom
                                    radius: width / 2
                                    color: Theme.accent
                                    Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }
                }
                // BLUETOOTH POPUP PANEL
                Item {
                    id: btPanel
                    width: 350
                    height: 68
                    anchors.centerIn: parent
                    
                    property bool isActiveBt: islandWindow.islandState === "bluetooth"
                    visible: isActiveBt
                    opacity: isActiveBt ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            width: 44; height: 44
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 12
                            color: Theme.accent
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰂱"
                                color: Theme.background
                                font.pixelSize: 24
                            }
                        }

                        // Text Info
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Row {
                                spacing: 8
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Connected"
                                    color: Theme.subtext
                                    font.pixelSize: 12
                                }
                                
                                Rectangle {
                                    visible: islandWindow.latestBtBattery !== "--"
                                    width: batRow.width + 12
                                    height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 9
                                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                                    
                                    Row {
                                        id: batRow
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: "󰥉"
                                            color: Theme.accent
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: islandWindow.latestBtBattery + "%"
                                            color: Theme.text
                                            font.pixelSize: 11
                                            font.bold: true
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            Text {
                                text: islandWindow.latestBtDevice
                                color: Theme.text
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                                width: 270 
                            }
                        }
                    }
                }
                // CALENDAR PANEL
                Item {
                    id: calendarPanel
                    width: 620
                    height: 250
                    anchors.centerIn: parent
                    layer.enabled: true
                    
                    property bool isActiveCalendar: islandWindow.islandState === "calendar"
                    visible: isActiveCalendar
                    opacity: isActiveCalendar ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    onVisibleChanged: {
                        if (visible) {
                            weatherDelayTimer.start()
                        } else {
                            calGrid.monthOffset = 0 
                        }
                    }

                    Text {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(new Date(), "HH:mm:ss • ddd, MMM d")
                        color: Theme.text
                        font.pixelSize: 14
                        font.bold: true
                        Timer {
                            interval: 1000; running: parent.visible; repeat: true
                            onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm:ss • ddd, MMM d")
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.topMargin: 32
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 32

                        // --- LEFT: CALENDAR ---
                        Column {
                            width: 290
                            height: parent.height
                            spacing: 12

                            Item {
                                width: parent.width; height: 24
                                Row {
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                                    Text { text: "󰃮"; color: Theme.accent; font.pixelSize: 18; anchors.baseline: monthText.baseline }
                                    Text { id: monthText; text: Qt.formatDateTime(calGrid.calDate, "MMMM yyyy"); color: Theme.text; font.pixelSize: 16; font.bold: true }
                                }
                                Row {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                    Rectangle {
                                        width: 24; height: 24; radius: 6
                                        color: prevHover.hovered ? Theme.accent : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: ""; color: prevHover.hovered ? Theme.background : Theme.accent; font.pixelSize: 16; font.bold: true }
                                        HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: calGrid.monthOffset-- }
                                    }
                                    Rectangle {
                                        width: 24; height: 24; radius: 6
                                        color: nextHover.hovered ? Theme.accent : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: ""; color: nextHover.hovered ? Theme.background : Theme.accent; font.pixelSize: 16; font.bold: true }
                                        HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: calGrid.monthOffset++ }
                                    }
                                }
                            }

                            Row {
                                width: parent.width; spacing: 4
                                Repeater {
                                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                                    Text {
                                        width: (parent.width - 24) / 7; horizontalAlignment: Text.AlignHCenter
                                        text: modelData; color: (index >= 5) ? Theme.accentAlt : Theme.subtext
                                        font.pixelSize: 12; font.bold: true
                                    }
                                }
                            }

                            Grid {
                                id: calGrid
                                width: parent.width
                                columns: 7; spacing: 4
                                
                                property int monthOffset: 0
                                property var calDate: {
                                    let d = new Date()
                                    d.setMonth(d.getMonth() + monthOffset)
                                    d.setDate(1); return d
                                }
                                property int startDay: (calDate.getDay() + 6) % 7
                                property int daysInMonth: new Date(calDate.getFullYear(), calDate.getMonth() + 1, 0).getDate()
                                property int today: new Date().getDate()

                                Repeater {
                                    model: 42 
                                    Rectangle {
                                        width: (calGrid.width - 24) / 7; height: 24; radius: 6
                                        
                                        property int day: index - calGrid.startDay + 1
                                        property bool isValidDay: day > 0 && day <= calGrid.daysInMonth
                                        property bool isToday: day === calGrid.today && calGrid.monthOffset === 0
                                        
                                        color: isToday ? Theme.accent : (dayHover.hovered && isValidDay ? Theme.surfaceHover : "transparent")
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.isValidDay ? parent.day : "" 
                                            color: parent.isToday ? Theme.background : Theme.text
                                            font.pixelSize: 13; font.bold: parent.isToday
                                        }

                                        HoverHandler {
                                            id: dayHover; enabled: parent.isValidDay; cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                            }
                        }

                        // --- RIGHT: WEATHER ---
                        Rectangle {
                            width: 274; height: parent.height; radius: 12
                            color: Qt.rgba(Theme.highlight.r, Theme.highlight.g, Theme.highlight.b, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: "󰖐   Fetching forecast..."
                                color: Theme.subtext
                                visible: islandWindow.weatherToday === null
                            }

                            Column {
                                anchors.fill: parent; anchors.margins: 14; spacing: 16
                                visible: islandWindow.weatherToday !== null

                                Row {
                                    spacing: 16; anchors.horizontalCenter: parent.horizontalCenter
                                    Text {
                                        text: islandWindow.weatherToday ? islandWindow.weatherIcon(islandWindow.weatherToday.icon) : ""
                                        color: Theme.accent; font.pixelSize: 46; anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: islandWindow.weatherToday ? islandWindow.weatherToday.temp + "°C" : ""; color: Theme.text; font.pixelSize: 26; font.bold: true }
                                        Text { text: islandWindow.weatherToday ? islandWindow.weatherToday.desc : ""; color: Theme.text; font.pixelSize: 13; font.bold: true }
                                        Text { text: islandWindow.weatherToday ? "H: " + islandWindow.weatherToday.high + "°  L: " + islandWindow.weatherToday.low + "°" : ""; color: Theme.subtext; font.pixelSize: 12 }
                                    }
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 10 // Tightened slightly to comfortably fit all 5 items
                                
                                // Rain Chance (PoP)
                                Row {
                                    spacing: 4
                                    Text { text: "󰖎"; color: "#60A5FA"; font.pixelSize: 14; anchors.baseline: popTxt.baseline }
                                    Text { id: popTxt; text: islandWindow.weatherToday ? islandWindow.weatherToday.pop + "%" : "--%"; color: Theme.subtext; font.pixelSize: 12; font.bold: true }
                                }
                                // Feels Like
                                Row {
                                    spacing: 4
                                    Text { text: ""; color: Theme.accentAlt; font.pixelSize: 13; anchors.baseline: feelsTxt.baseline }
                                    Text { id: feelsTxt; text: islandWindow.weatherToday ? islandWindow.weatherToday.feels + "°" : "--°"; color: Theme.subtext; font.pixelSize: 12; font.bold: true }
                                }
                                // Wind
                                Row {
                                    spacing: 4
                                    Text { text: "󰖝"; color: Theme.accentAlt; font.pixelSize: 13; anchors.baseline: windTxt.baseline }
                                    Text { id: windTxt; text: islandWindow.weatherToday ? islandWindow.weatherToday.wind + " km/h" : "--"; color: Theme.subtext; font.pixelSize: 12; font.bold: true }
                                }
                                // Sunrise
                                Row {
                                    spacing: 4
                                    Text { text: "󰖜"; color: Theme.accentAlt; font.pixelSize: 14; anchors.baseline: sunriseTxt.baseline }
                                    Text { id: sunriseTxt; text: islandWindow.weatherToday ? islandWindow.weatherToday.sunrise : "--:--"; color: Theme.subtext; font.pixelSize: 12; font.bold: true }
                                }
                                // Sunset
                                Row {
                                    spacing: 4
                                    Text { text: "󰖛"; color: Theme.accentAlt; font.pixelSize: 14; anchors.baseline: sunsetTxt.baseline }
                                    Text { id: sunsetTxt; text: islandWindow.weatherToday ? islandWindow.weatherToday.sunset : "--:--"; color: Theme.subtext; font.pixelSize: 12; font.bold: true }
                                }
                                }

                                Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2) }

                                Grid {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    columns: 2; columnSpacing: 24; rowSpacing: 10
                                    Repeater {
                                        model: islandWindow.weatherForecast
                                        Row {
                                            spacing: 8
                                            Text { text: modelData.day; color: Theme.subtext; font.pixelSize: 13; font.bold: true; width: 30; anchors.baseline: forecastHigh.baseline }
                                            Text { text: islandWindow.weatherIcon(modelData.icon); color: Theme.accentAlt; font.pixelSize: 14; anchors.baseline: forecastHigh.baseline }
                                            Text { id: forecastHigh; text: modelData.high + "°"; color: Theme.text; font.pixelSize: 13; font.bold: true }
                                            Text { text: modelData.low + "°"; color: Theme.subtext; font.pixelSize: 12; anchors.baseline: forecastHigh.baseline }
                                            Text { text: "󰖎" + modelData.pop + "%"; color: "#60A5FA"; font.pixelSize: 10; font.bold: true; anchors.baseline: forecastHigh.baseline; visible: modelData.pop >= 20 }
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