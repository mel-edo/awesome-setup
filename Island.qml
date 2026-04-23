import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
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
        mask: Region { item: pill }
        property var cavaValues: []
        property bool cavaActive: false
        property bool showClock: true
        property string islandState: "idle"
        property bool isHovered: false
        property bool postHubCava: false
        property var weatherToday: null
        property var weatherForecast: []
        property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
        property int osdValue: 50
        property string osdType: "volume"

        function closeToIdle() {
            islandState = "idle"
            hubStayTimer.stop()
            idleStayTimer.stop()
        }

        function weatherIcon(code) {
            let isNight = code.endsWith("n")

            if (code.startsWith("01")) return isNight ? "󰖔" : "󰖙"  // clear: Moon / Sun
            if (code.startsWith("02")) return isNight ? "󰖡" : "󰖕"  // few clouds: Moon+Cloud / Sun+Cloud
            if (code.startsWith("03") || code.startsWith("04")) return "󰖐"  // scattered/broken clouds
            if (code.startsWith("09") || code.startsWith("10")) return "󰖗"  // rain
            if (code.startsWith("11")) return "󰖓"  // thunderstorm
            if (code.startsWith("13")) return "󰖘"  // snow
            if (code.startsWith("50")) return "󰖑"  // mist/fog
            return isNight ? "󰖔" : "󰖙" // fallback
        }

        function showOsd(value, type) {
            osdValue = value
            osdType = type
            islandWindow.islandState = "osd"
            osdTimeoutTimer.restart()
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
                islandWindow.islandState = "idle" // Shrink down!
                if (islandWindow.cavaActive && islandWindow.postHubCava) {
                    idleStayTimer.start() // Hand off to Phase 2
                } else {
                    islandWindow.closeToIdle()
                }
            }
        }

        Timer {
            id: idleStayTimer
            interval: 3000 // 3 solid seconds in the Idle Cava state before clock returns
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
            interval: 2000 // Stays open for 2 seconds after the last volume change
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

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: {
                if (islandWindow.islandState === "idle") return 180
                if (islandWindow.islandState === "calendar") return 660
                if (islandWindow.islandState === "osd") return 260
                return 350
            }
            height: {
                if (islandWindow.islandState === "idle") return 34
                if (islandWindow.islandState === "calendar") return 290
                if (islandWindow.islandState === "osd") return 40
                return 68
            }
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 16
            bottomRightRadius: 16
            color: Theme.surface
            clip: true

            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

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
                            // Music is playing: Do the 2-phase smooth Cava step-down
                            islandWindow.islandState = "media" 
                            islandWindow.postHubCava = true
                            islandWindow.showClock = false
                            alternateTimer.stop()
                            hubStayTimer.start()
                        } else {
                            // No music: Shrink directly back to the idle clock!
                            islandWindow.closeToIdle()
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 8

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(new Date(), "HH:mm:ss • ddd, MMM dd")
                    color: Theme.text
                    font.pixelSize: 14
                    property bool isActiveText: islandWindow.islandState === "idle" && 
                                        !islandWindow.postHubCava && 
                                        (!islandWindow.cavaActive || islandWindow.showClock)
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

                Row {
                    id: cavaRow
                    anchors.fill: parent
                    spacing: 4
                    property bool isActiveCava: islandWindow.islandState === "idle" && 
                                                (islandWindow.postHubCava || (islandWindow.cavaActive && !islandWindow.showClock))
                    visible: isActiveCava
                    opacity: isActiveCava ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    Repeater {
                        // Safely grab the length of the array
                        model: islandWindow.cavaValues ? islandWindow.cavaValues.length : 0
                        
                        Rectangle {
                            // Automatically calculate width based on spacing and available space
                            width: (cavaRow.width - (cavaRow.spacing * (islandWindow.cavaValues.length - 1))) / Math.max(1, islandWindow.cavaValues.length)
                            
                            // Height math (keeping your / 9 formula, but capping it so it never breaks out of the pill)
                            height: {
                                let val = islandWindow.cavaValues[index] || 0
                                let h = (val / 9) * cavaRow.height
                                return Math.max(3, Math.min(h, cavaRow.height)) // Min 3px, Max full height
                            }
                            
                            anchors.bottom: parent.bottom
                            radius: width / 2
                            color: Theme.accent
                            
                            // This makes the bars bounce smoothly instead of jittering!
                            Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutQuad } }
                        }
                    }
                }

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
                            width: 32
                            height: 32

                            // Background highlight
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: parent.modelData.accent
                                opacity: hubBtnHover.hovered ? 0.2 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            // Icon
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.icon
                                font.pixelSize: 16
                                color: hubBtnHover.hovered ? parent.modelData.accent : Theme.text
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            HoverHandler {
                                id: hubBtnHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: islandWindow.islandState = parent.modelData.state
                            }
                        }
                    }
                }
                Item {
                    id: osdPanel
                    width: 240
                    height: 40
                    anchors.centerIn: parent
                    
                    property bool isActiveOsd: islandWindow.islandState === "osd"
                    visible: isActiveOsd
                    opacity: isActiveOsd ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12
                        anchors.verticalCenter: parent.verticalCenter

                        // Dynamic Icon
                        Text {
                            text: islandWindow.osdType === "volume" ? "󰕾" : "󰃠" 
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

                            // Slider Fill (Bound to osdValue out of 100)
                            Rectangle {
                                width: (islandWindow.osdValue / 100) * parent.width 
                                height: parent.height
                                radius: 3
                                color: Theme.accent
                                
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
                Item {
                    id: mediaPanel
                    width: 340
                    height: 80
                    anchors.centerIn: parent
                    
                    property bool isActiveMedia: islandWindow.islandState === "media"
                    visible: isActiveMedia
                    opacity: isActiveMedia ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // LEFT: Album Art
                        Rectangle {
                            width: 52
                            height: 52
                            radius: 10
                            color: Theme.surfaceHover
                            clip: true
                            Image {
                                id: albumArt
                                anchors.fill: parent
                                source: islandWindow.activePlayer && islandWindow.activePlayer.trackArtUrl ? islandWindow.activePlayer.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰝚"
                                color: Theme.subtext
                                font.pixelSize: 24
                                visible: albumArt.status !== Image.Ready
                            }
                        }

                        // MIDDLE: Track Info
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 140 
                            Text { 
                                text: islandWindow.activePlayer ? (islandWindow.activePlayer.tracktitle || "Unknown Track") : "No Media"
                                color: Theme.text; font.pixelSize: 14; font.bold: true
                                elide: Text.ElideRight; width: parent.width 
                            }
                            Text { 
                                text: islandWindow.activePlayer ? (islandWindow.activePlayer.trackArtist || "Unknown Artist") : ""
                                color: Theme.subtext; font.pixelSize: 12
                                elide: Text.ElideRight; width: parent.width 
                            }
                        }

                        // RIGHT: Cava Visualizer
                        Row {
                            width: 100 // This fixed width makes your bars thin again!
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Repeater {
                                model: islandWindow.cavaValues ? islandWindow.cavaValues.length : 0
                                
                                Rectangle {
                                    width: (parent.width - (parent.spacing * (islandWindow.cavaValues.length - 1))) / Math.max(1, islandWindow.cavaValues.length)
                                    
                                    height: {
                                        let val = islandWindow.cavaValues[index] || 0
                                        let h = (val / 9) * parent.height
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
                            calGrid.monthOffset = 0 // Reset to current month on close
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
                            interval: 1000
                            running: parent.visible
                            repeat: true
                            onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm:ss • ddd, MMM d")
                        }
                    }

                    // Side-by-Side Container
                    Row {
                        anchors.fill: parent
                        anchors.topMargin: 32
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 32

                        // --- LEFT SIDE: CALENDAR ---
                        Column {
                            width: 290
                            height: parent.height
                            spacing: 12

                            // Header
                            Item {
                                width: parent.width
                                height: 24

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    
                                    Text { 
                                        id: calIcon
                                        text: "󰃮"
                                        color: Theme.accent
                                        font.pixelSize: 18
                                        anchors.baseline: monthText.baseline
                                    }
                                    Text {
                                        id: monthText
                                        text: Qt.formatDateTime(calGrid.calDate, "MMMM yyyy")
                                        color: Theme.text
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                }

                                // Navigation Arrows
                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

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

                            // Days of Week
                            Row {
                                width: parent.width
                                spacing: 4
                                Repeater {
                                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                                    Text {
                                        width: (parent.width - 24) / 7
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData
                                        color: (index >= 5) ? Theme.accentAlt : Theme.subtext
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }
                            }

                            // 42-Cell Grid
                            Grid {
                                id: calGrid
                                width: parent.width
                                columns: 7
                                spacing: 4
                                
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
                                        width: (calGrid.width - 24) / 7
                                        height: 24 // Slightly shorter to fit the fixed height perfectly
                                        radius: 6
                                        
                                        property int day: index - calGrid.startDay + 1
                                        property bool isValidDay: day > 0 && day <= calGrid.daysInMonth
                                        property bool isToday: day === calGrid.today && calGrid.monthOffset === 0
                                        
                                        color: isToday ? Theme.accent : (dayHover.hovered && isValidDay ? Theme.surfaceHover : "transparent")
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.isValidDay ? parent.day : "" 
                                            color: parent.isToday ? Theme.background : Theme.text
                                            font.pixelSize: 13
                                            font.bold: parent.isToday
                                        }

                                        HoverHandler {
                                            id: dayHover
                                            enabled: parent.isValidDay 
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                            }
                        }

                        // --- RIGHT SIDE: WEATHER WIDGET ---
                        Rectangle {
                            width: 274 // Takes up the remaining space inside the Row
                            height: parent.height
                            radius: 12
                            color: Qt.rgba(Theme.highlight.r, Theme.highlight.g, Theme.highlight.b, 0.15)

                            // Loading State
                            Text {
                                anchors.centerIn: parent
                                text: "󰖐   Fetching forecast..."
                                color: Theme.subtext
                                visible: islandWindow.weatherToday === null
                            }

                            // Loaded State
                            Column {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 16
                                visible: islandWindow.weatherToday !== null

                                // --- TOP SECTION: Main Info ---
                                Row {
                                    spacing: 16
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    
                                    Text {
                                        text: islandWindow.weatherToday ? islandWindow.weatherIcon(islandWindow.weatherToday.icon) : ""
                                        color: Theme.accent
                                        font.pixelSize: 46
                                        anchors.verticalCenter: parent.verticalCenter // Kept verticalCenter here because it's aligning with a multi-line column
                                    }
                                    
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            text: islandWindow.weatherToday ? islandWindow.weatherToday.temp + "°C" : ""
                                            color: Theme.text
                                            font.pixelSize: 26
                                            font.bold: true
                                        }
                                        Text {
                                            text: islandWindow.weatherToday ? islandWindow.weatherToday.desc : ""
                                            color: Theme.text
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                        Text {
                                            text: islandWindow.weatherToday ? "H: " + islandWindow.weatherToday.high + "°  L: " + islandWindow.weatherToday.low + "°" : ""
                                            color: Theme.subtext
                                            font.pixelSize: 12
                                        }
                                    }
                                }

                                // --- MIDDLE SECTION: Secondary Stats ---
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

                                // Divider
                                Rectangle { 
                                    width: parent.width; height: 1; 
                                    color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2) 
                                }

                                // --- BOTTOM SECTION: Forecast Grid ---
                                Grid {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    columns: 2
                                    columnSpacing: 24
                                    rowSpacing: 10
                                    
                                    Repeater {
                                        model: islandWindow.weatherForecast
                                        Row {
                                            spacing: 8
                                            
                                            // Day of the Week (Fixed width so the grid aligns perfectly)
                                            Text {
                                                text: modelData.day
                                                color: Theme.subtext
                                                font.pixelSize: 13
                                                font.bold: true
                                                width: 30 
                                                anchors.baseline: forecastHigh.baseline
                                            }
                                            
                                            // Icon
                                            Text {
                                                text: islandWindow.weatherIcon(modelData.icon)
                                                color: Theme.accentAlt
                                                font.pixelSize: 14
                                                anchors.baseline: forecastHigh.baseline
                                            }
                                            
                                            // High Temp
                                            Text {
                                                id: forecastHigh
                                                text: modelData.high + "°"
                                                color: Theme.text
                                                font.pixelSize: 13
                                                font.bold: true
                                            }
                                            
                                            // Low Temp
                                            Text {
                                                text: modelData.low + "°"
                                                color: Theme.subtext
                                                font.pixelSize: 12
                                                anchors.baseline: forecastHigh.baseline
                                            }

                                            // Rain Chance (Only shows if 20% or higher!)
                                            Text {
                                                text: "󰖎" + modelData.pop + "%"
                                                color: "#60A5FA" 
                                                font.pixelSize: 10
                                                font.bold: true
                                                anchors.baseline: forecastHigh.baseline 
                                                visible: modelData.pop >= 20 
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