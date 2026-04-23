import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick.Shapes
import QtQuick.Effects
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
        mask: Region { item: clickMask }
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

        function closeToIdle() {
            islandState = "idle"
            hubStayTimer.stop()
            idleStayTimer.stop()
        }

        function weatherIcon(code) {
            let isNight = code.endsWith("n")
            if (code.startsWith("01")) return isNight ? "󰖔" : "󰖙" 
            if (code.startsWith("02")) return isNight ? "󰖡" : "󰖕" 
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
            osdTimeoutTimer.restart()
        }

        function showMediaPopup() {
            if (islandWindow.islandState === "osd" || islandWindow.islandState === "calendar") return
            islandWindow.islandState = "media"
            islandWindow.postHubCava = true
            islandWindow.showClock = false
            alternateTimer.stop()
            hubStayTimer.restart()
        }

        Timer {
            id: alternateTimer
            interval: islandWindow.showClock ? 10000 : 7000
            running: islandWindow.cavaActive
            repeat: true
            onTriggered: {
                islandWindow.showClock = !islandWindow.showClock
                interval = islandWindow.showClock ? 10000 : 7000
            }
        }

        Timer {
            interval: 2000
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
            interval: 2000 
            onTriggered: {
                islandWindow.closeToIdle()
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
                            islandWindow.cavaActive = true
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

        // --- THE SPLIT PILL ARCHITECTURE ---
        Item {
            id: clickMask
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: Math.max(mainPill.width, dropPill.width)
            height: Math.max(mainPill.height, dropPill.y + dropPill.height)
            // --- THE DYNAMIC LIQUID BRIDGE ---
            Shape {
                id: liquidBridge
                z: 3
                anchors.horizontalCenter: parent.horizontalCenter
                y: 15 // Tucked 1px higher to prevent any gap
                width: 240
                height: Math.max(0, dropPill.y + 20 - y) 
                
                opacity: dropPill.opacity
                visible: opacity > 0

                // ENGINE FIXES: Forces perfectly smooth vector rendering!
                antialiasing: true
                smooth: true
                layer.enabled: true
                layer.samples: 4

                property real leftEdge: 120 - (dropPill.width / 2) + 20
                property real rightEdge: 120 + (dropPill.width / 2) - 20

                // LAYER 1: Accent Aura
                ShapePath {
                    fillColor: Theme.surface
                    strokeColor: Theme.surface
                    strokeWidth: 1 // Seals the sub-pixel gap!

                    startX: 75; startY: 0
                    PathCubic {
                        x: liquidBridge.leftEdge - 4; y: liquidBridge.height + 3
                        control1X: 75; control1Y: liquidBridge.height * 0.5 
                        control2X: liquidBridge.leftEdge - 4; control2Y: liquidBridge.height * 0.5 
                    }
                    PathLine { x: liquidBridge.rightEdge + 4; y: liquidBridge.height + 3 }
                    PathCubic {
                        x: 165; y: 0
                        control1X: liquidBridge.rightEdge + 4; control1Y: liquidBridge.height * 0.5 
                        control2X: 165; control2Y: liquidBridge.height * 0.5 
                    }
                }
                
                // LAYER 2: Main Surface
                ShapePath {
                    fillColor: Theme.accent
                    strokeColor: Theme.accent
                    strokeWidth: 1 // Seals the sub-pixel gap!

                    startX: 75; startY: 0
                    PathCubic {
                        x: liquidBridge.leftEdge; y: liquidBridge.height
                        control1X: 75; control1Y: liquidBridge.height * 0.5
                        control2X: liquidBridge.leftEdge; control2Y: liquidBridge.height * 0.5
                    }
                    PathLine { x: liquidBridge.rightEdge; y: liquidBridge.height }
                    PathCubic {
                        x: 165; y: 0
                        control1X: liquidBridge.rightEdge; control1Y: liquidBridge.height * 0.5
                        control2X: 165; control2Y: liquidBridge.height * 0.5
                    }
                }
            }

            // 1. THE DROP PILL (OSD & Notifications)
            Rectangle {
                id: dropPill
                z: 4
                height: 40
                radius: height / 2
                color: Theme.surface
                anchors.horizontalCenter: parent.horizontalCenter
                
                property bool isActiveOsd: islandWindow.islandState === "osd"

                width: isActiveOsd ? 240 : 40
                y: isActiveOsd ? 44 : 16
                opacity: isActiveOsd ? 1 : 0
                visible: opacity > 0 || y > 18
                Behavior on opacity { NumberAnimation { duration: 300 } }

                // TWO-STAGE PHYSICS: Horizontal vs Vertical
                Behavior on width {
                    SequentialAnimation {
                        // When OPENING: Wait 200ms for Y to drop first. When CLOSING: Collapse width immediately (0ms).
                        PauseAnimation { duration: dropPill.isActiveOsd ? 200 : 0 }
                        NumberAnimation { 
                            duration: 550 
                            easing.type: dropPill.isActiveOsd ? Easing.OutExpo : Easing.InOutQuad 
                        }
                    }
                }

                Behavior on y {
                    SequentialAnimation {
                        // When OPENING: Drop Y immediately (0ms). When CLOSING: Wait 300ms for Width to collapse first!
                        PauseAnimation { duration: dropPill.isActiveOsd ? 0 : 300 }
                        NumberAnimation { 
                            duration: 600 
                            easing.type: dropPill.isActiveOsd ? Easing.OutBack : Easing.InBack 
                            easing.overshoot: 1.3 
                        }
                    }
                }
                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: dropPill.width > 200 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    // Dynamic Icon
                    Text {
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
                        color: Theme.text
                        font.pixelSize: 18
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Slider Track
                    Rectangle {
                        width: 180
                        height: 6
                        radius: 3
                        color: Theme.surfaceHover
                        anchors.verticalCenter: parent.verticalCenter

                        // Slider Fill
                        Rectangle {
                            width: (Math.min(islandWindow.osdValue, 100) / 100) * parent.width
                            height: parent.height
                            radius: 3
                            color: islandWindow.osdValue > 100 ? Theme.danger : Theme.accent
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }
            }

            // 2. THE MAIN PILL (Clock, Hub, Media, Calendar)
            Rectangle {
                id: mainPill
                z: 10 // Renders ON TOP of the drop pill
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                
                width: {
                    if (islandWindow.islandState === "idle" || islandWindow.islandState === "osd" ) return 180
                    if (islandWindow.islandState === "calendar") return 660
                    return 350
                }
                height: {
                    if (islandWindow.islandState === "idle" || islandWindow.islandState === "osd") return 34
                    if (islandWindow.islandState === "calendar") return 290
                    return 68
                }
                
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: 16
                bottomRightRadius: 16
                color: Theme.surface
                clip: true

                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                HoverHandler {
                    id: pillHover
                    onHoveredChanged: {
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

                    // IDLE CLOCK
                    Text {
                        id: clockText
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 1
                        text: Qt.formatDateTime(new Date(), "HH:mm:ss • ddd, MMM dd")
                        color: Theme.text
                        font.pixelSize: 14
                        
                        property bool isActiveText: islandWindow.islandState === "osd" || 
                                                    (islandWindow.islandState === "idle" && !islandWindow.postHubCava && (!islandWindow.cavaActive || islandWindow.showClock))
                        visible: isActiveText
                        opacity: isActiveText ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

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
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                        Repeater {
                            model: islandWindow.cavaValues ? islandWindow.cavaValues.length : 0
                            Rectangle {
                                width: (cavaRow.width - (cavaRow.spacing * (islandWindow.cavaValues.length - 1))) / Math.max(1, islandWindow.cavaValues.length)
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
                                width: 32; height: 32
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: parent.modelData.accent
                                    opacity: hubBtnHover.hovered ? 0.2 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.icon
                                    font.pixelSize: 16
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
                                        width: (parent.width - (parent.spacing * (islandWindow.cavaValues.length - 1))) / Math.max(1, islandWindow.cavaValues.length)
                                        height: {
                                            let val = islandWindow.cavaValues[index] || 0
                                            // Scaled to fit the new 52px height nicely
                                            let h = (val / 9) * (parent.height * 0.7) 
                                            return Math.max(3, Math.min(h, parent.height))
                                        }
                                        anchors.bottom: parent.bottom // Anchors to the floor perfectly!
                                        radius: width / 2
                                        color: Theme.accent
                                        Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutQuad } }
                                    }
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
                                            color: prevHover.hovered ? Theme.surfaceHover : "transparent"
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                            Text { anchors.centerIn: parent; text: ""; color: Theme.accent; font.pixelSize: 16; font.bold: true }
                                            HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                                            TapHandler { onTapped: calGrid.monthOffset-- }
                                        }
                                        Rectangle {
                                            width: 24; height: 24; radius: 6
                                            color: nextHover.hovered ? Theme.surfaceHover : "transparent"
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                            Text { anchors.centerIn: parent; text: ""; color: Theme.accent; font.pixelSize: 16; font.bold: true }
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
}