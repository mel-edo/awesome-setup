import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "."

Scope {
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

        function closeToIdle() {
            islandState = "idle"
            hubRetractTimer.stop()
            idleRetractTimer.stop()
            postHubCavaTimer.stop()
        }

        function weatherIcon(code) {
            if (code.startsWith("01")) return "󰖙"  // clear
            if (code.startsWith("02")) return "󰖕"  // few clouds
            if (code.startsWith("03") || code.startsWith("04")) return "󰖔"  // clouds
            if (code.startsWith("09") || code.startsWith("10")) return "󰖗"  // rain
            if (code.startsWith("11")) return "󰖓"  // thunder
            if (code.startsWith("13")) return "󰖘"  // snow
            if (code.startsWith("50")) return "󰖑"  // mist
            return "󰖙"
        }

        Timer {
            id: alternateTimer
            interval: showClock ? 10000 : 7000  // won't work directly, use a fixed approach
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
                alternateTimer.stop()
            }
        }

        Timer {
            id: hubRetractTimer
            interval: 300
            onTriggered: islandWindow.islandState = "idle"
        }

        Timer {
            id: hubStepTimer
            interval: 1200 // Stays expanded at the hub for 1.2 seconds before retracting fully
            onTriggered: {
                if (islandWindow.cavaActive) {
                    islandWindow.postHubCava = true
                    postHubCavaTimer.start()
                } else {
                    islandWindow.closeToIdle()
                }
            }
        }

        Timer {
            id: idleRetractTimer  
            interval: 600
            onTriggered: {
                if (islandWindow.cavaActive) {
                    islandWindow.postHubCava = true
                    postHubCavaTimer.start()
                } else {
                    islandWindow.closeToIdle()
                }
            }
        }

        Timer {
            id: postHubCavaTimer
            interval: 4000
            onTriggered: {
                islandWindow.postHubCava = false
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
                if (islandWindow.islandState === "idle" && !islandWindow.postHubCava) return 180
                if (islandWindow.islandState === "calendar") return 520
                return 300
            }
            height: {
                if (islandWindow.islandState === "idle" && !islandWindow.postHubCava) return 34
                if (islandWindow.islandState === "calendar") return 320
                return 55
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
                        idleRetractTimer.stop()
                        hubRetractTimer.stop()
                        postHubCavaTimer.stop()
                        hubStepTimer.stop()
                        islandWindow.postHubCava = false
                        hubDelayTimer.start()
                    } else {
                        // The Stepped Retraction Logic
                        if (islandWindow.islandState !== "idle" && islandWindow.islandState !== "hub") {
                            islandWindow.islandState = "hub"
                            hubStepTimer.start() // Pause at hub, then go to idle
                        } else {
                            idleRetractTimer.start()
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
                    text: Qt.formatDateTime(new Date(), "HH:mm:ss | ddd, MMM dd")
                    color: Theme.text
                    font.pixelSize: 13
                    opacity: islandWindow.islandState === "idle" && 
                             !islandWindow.postHubCava && 
                             (!islandWindow.cavaActive || islandWindow.showClock) ? 1 : 0
                             
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm:ss | ddd, MMM dd")
                    }
                }

                Row {
                    id: cavaRow
                    anchors.fill: parent
                    spacing: 4
                    opacity: islandWindow.postHubCava || 
                             (islandWindow.islandState === "idle" && islandWindow.cavaActive && !islandWindow.showClock) ? 1 : 0
                             
                    Behavior on opacity { NumberAnimation { duration: 150 } }

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
                    opacity: islandWindow.islandState === "hub" && !islandWindow.postHubCava ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 80 } }

                    Repeater {
                        model: [
                            { icon: "󰃶", state: "calendar", accent: Theme.accent },
                            { icon: "󰂚", state: "notifications", accent: Theme.accentAlt },
                            { icon: "󱉐", state: "wallpaper", accent: Theme.border }
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
                    id: calendarPanel
                    width: 460
                    height: 300
                    anchors.centerIn: parent
                    layer.enabled: true
                    
                    opacity: islandWindow.islandState === "calendar" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: islandWindow.islandState === "calendar" ? 200 : 0 } }

                    onVisibleChanged: {
                        if (visible) {
                            weatherDelayTimer.start()
                        } else {
                            calGrid.monthOffset = 0
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        width: 460
                        spacing: 8

                    // --- HEADER ---
                        Item {
                            width: parent.width
                            height: 24

                            // Left side: Icon and Current Month
                            Row {
                                anchors.left: parent.left
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Text {
                                    text: "󰃮"
                                    color: Theme.accent
                                    font.pixelSize: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    // Crucial: This now binds to the grid's calculated date
                                    text: Qt.formatDateTime(calGrid.calDate, "MMMM yyyy")
                                    color: Theme.text
                                    font.pixelSize: 16
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Right side: Navigation Buttons
                            Row {
                                anchors.right: parent.right
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter

                                // Previous Month Button
                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 6
                                    color: prevMonthHover.hovered ? Theme.surfaceHover : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "<" // Swap with a Nerd Font icon like "󰁔" if preferred
                                        color: Theme.accent
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                    
                                    HoverHandler { id: prevMonthHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: calGrid.monthOffset-- }
                                }

                                // Next Month Button
                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 6
                                    color: nextMonthHover.hovered ? Theme.surfaceHover : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: ">" // Swap with a Nerd Font icon like "󰁍" if preferred
                                        color: Theme.accent
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                    
                                    HoverHandler { id: nextMonthHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: calGrid.monthOffset++ }
                                }
                            }
                        }
                        // --- CALENDAR GRID ---
                        Column {
                            width: parent.width
                            spacing: 8

                            // Days of the week
                            Row {
                                width: parent.width
                                spacing: 4
                                Repeater {
                                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                                    Text {
                                        width: (calendarPanel.width - 8) / 7
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData
                                        color: (index >= 5) ? Theme.accentAlt : Theme.subtext
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }
                            }

                            // Dates
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
                                    model: calGrid.startDay + calGrid.daysInMonth
                                    Rectangle {
                                        width: (calendarPanel.width - 8) / 7
                                        height: 28
                                        radius: 6
                                        
                                        property int day: index - calGrid.startDay + 1
                                        property bool isToday: day === calGrid.today && calGrid.monthOffset === 0
                                        property bool isEmpty: index < calGrid.startDay
                                        
                                        // Highlight today, add hover effect for other days
                                        color: isToday ? Theme.accent : 
                                               (dayHover.hovered && !isEmpty ? Theme.surfaceHover : "transparent")
                                               
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.isEmpty ? "" : parent.day
                                            color: parent.isToday ? Theme.background : Theme.text
                                            font.pixelSize: 13
                                            font.bold: parent.isToday
                                        }

                                        HoverHandler {
                                            id: dayHover
                                            enabled: !parent.isEmpty
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                            }
                        }

                        // --- WEATHER CARD ---
                        Rectangle {
                            width: parent.width
                            height: 60
                            radius: 12
                            // Creates a distinct, semi-transparent card background for the weather
                            color: Qt.rgba(Theme.highlight.r, Theme.highlight.g, Theme.highlight.b, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: "󰖐  Fetching forecast..."
                                color: Theme.subtext
                                font.pixelSize: 13
                                visible: islandWindow.weatherToday === null
                            }

                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 16
                                visible: islandWindow.weatherToday !== null

                                // Today's Main Weather
                                Row {
                                    spacing: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: islandWindow.weatherToday ? islandWindow.weatherIcon(islandWindow.weatherToday.icon) : ""
                                        color: Theme.accent
                                        font.pixelSize: 28
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            text: islandWindow.weatherToday ? islandWindow.weatherToday.temp + "°C" : ""
                                            color: Theme.text
                                            font.pixelSize: 16
                                            font.bold: true
                                        }
                                        Text {
                                            text: islandWindow.weatherToday ? islandWindow.weatherToday.desc : ""
                                            color: Theme.subtext
                                            font.pixelSize: 11
                                        }
                                    }
                                }

                                // Vertical Divider
                                Rectangle {
                                    width: 1
                                    height: parent.height - 10
                                    color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // 4-Day Forecast
                                Row {
                                    spacing: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Repeater {
                                        model: islandWindow.weatherForecast
                                        Column {
                                            spacing: 4
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: islandWindow.weatherIcon(modelData.icon)
                                                color: Theme.accentAlt
                                                font.pixelSize: 14
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: modelData.temp + "°"
                                                color: Theme.text
                                                font.pixelSize: 11
                                                font.bold: true
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