import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "."

Column {
    id: root
    spacing: 16
    property bool isOpen: false
    property QtObject parentWindow: null
    property string netSsid: ""
    property int netSignal: 0
    property bool btConnected: false
    property int batLevel: 100
    property string batStatus: "Discharging"
    property bool wifiEnabled: true
    property bool btEnabled: true
    property var wifiNetworks: []
    property var savedNetworks: []
    property var btDevices: []
    property string powerProfile: "balanced"
    property string batTimeLeft: ""
    property string connectingWifi: ""
    property string connectingBt: ""
    property string passwordSsid: ""
    property string passwordText: ""
    property bool passwordVisible: false
    property bool isScanningBt: false
    property var visibleBtDevices: btDevices.filter(d => isScanningBt || d.paired === "1" || d.connected === "1")

    property int volLevel: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) : 50
    property int briLevel: 50
    property bool isDraggingSlider: volDragArea.pressed || briDragArea.pressed
    onIsDraggingSliderChanged: SharedState.isSuppressingOsd = isDraggingSlider
    
    Timer { id: resetConnectingWifi; interval: 3000; onTriggered: root.connectingWifi = "" }
    Timer { id: resetConnectingBt; interval: 3000; onTriggered: root.connectingBt = "" }

    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() {
            if (!root.isDraggingSlider) {
                root.volLevel = Math.round(Pipewire.defaultAudioSink.audio.volume * 100);
            }
        }
    }
    
    Process {
        id: briFetchProcess
        command: ["bash", "-c", "brightnessctl -m | awk -F, '{print int($4)}'"]
        stdout: StdioCollector { onStreamFinished: root.briLevel = parseInt(text.trim()) || 0 }
    }

    Process {
        id: savedWifiFetchProcess
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n")
                let saved = []
                for (let line of lines) {
                    let parts = line.split(":")
                    if (parts.length >= 2 && parts[1].includes("wireless")) {
                        saved.push(parts[0]) // Push the SSID/Connection Name
                    }
                }
                root.savedNetworks = saved
            }
        }
    }

    Process {
        id: wifiRescanProcess
        command: ["nmcli", "dev", "wifi", "rescan"]
        onRunningChanged: {
            if (!running && !wifiListProcess.running) {
                wifiListProcess.running = true
            }
        }
    }

    Process {
        id: wifiListProcess
        command: [Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/watchers/wifi_list.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n").filter(x => x !== "")
                let nets = []
                for (let line of lines) {
                    let parts = line.split(":")
                    if (parts.length >= 3 && parts[0] !== "" && parts[0] !== root.netSsid) {
                        nets.push({ ssid: parts[0], signal: parseInt(parts[1]) || 0, security: parts[2] || "" })
                    }
                }
                root.wifiNetworks = nets
            }
        }
    }

    Process {
        id: btListProcess
        command: [Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/watchers/bt_list.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n").filter(x => x !== "")
                let devs = []
                for (let line of lines) {
                    let parts = line.split("|")
                    if (parts.length >= 5) {
                        devs.push({ mac: parts[0], name: parts[1], connected: parts[2], battery: parts[3], paired: parts[4] })
                    }
                }
                root.btDevices = devs
            }
        }
    }

    Process {
        id: profileFetchProcess
        command: [Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/watchers/power_profile.sh"]
        stdout: StdioCollector { onStreamFinished: root.powerProfile = text.trim() }
    }

    Process {
        id: batTimeProcess
        command: ["bash", "-c", "upower -i /org/freedesktop/UPower/devices/battery_BAT1 2>/dev/null | grep 'time to' | awk '{print $4, $5}'"]
        stdout: StdioCollector { onStreamFinished: root.batTimeLeft = text.trim() }
    }

    // Toggles and Actions
    Process { id: wifiToggleProcess }
    Process { id: btToggleProcess }
    Process { id: wifiConnectProcess }
    Process { id: btActionProcess }
    Process { id: btScanProcess }
    Process { id: profileProcess }
    Process { id: volSetProcess }
    Process { id: briSetProcess }

    Process {
        id: wifiConnectWithPassProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.passwordSsid = ""
                root.passwordText = ""
                root.passwordVisible = false
                Qt.callLater(() => { if (!wifiListProcess.running) wifiListProcess.running = true })
            }
        }
    }

    Timer { interval: 10000; running: root.isOpen; repeat: true; onTriggered: { if (!wifiListProcess.running) wifiListProcess.running = true; if (!savedWifiFetchProcess.running) savedWifiFetchProcess.running = true } }
    Timer { interval: 5000; running: root.isOpen; repeat: true; onTriggered: { if (!btListProcess.running) btListProcess.running = true; if (!batTimeProcess.running) batTimeProcess.running = true } }
    
    Timer { 
        interval: 1000; 
        running: root.isOpen && !root.isDraggingSlider; 
        repeat: true; 
        onTriggered: { 
            if (!briFetchProcess.running) briFetchProcess.running = true; 
        } 
    }

    onIsOpenChanged: {
        if (isOpen) {
            if (!savedWifiFetchProcess.running) savedWifiFetchProcess.running = true
            if (!wifiListProcess.running) wifiListProcess.running = true
            if (!btListProcess.running) btListProcess.running = true
            if (!profileFetchProcess.running) profileFetchProcess.running = true
            if (!batTimeProcess.running) batTimeProcess.running = true
            if (!volFetchProcess.running) volFetchProcess.running = true
            if (!briFetchProcess.running) briFetchProcess.running = true
        } else {
            root.passwordSsid = ""
            root.passwordText = ""
            root.passwordVisible = false
            root.isScanningBt = false
        }
    }

    // Network section
    Column {
        width: parent.width
        spacing: 8

        Item {
            width: parent.width
            height: 28

            Text {
                text: "󰤨   Network"
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    id: rescanIcon
                    text: "󰑐"
                    font.pixelSize: 14
                    
                    color: wifiRescanTap.pressed ? Qt.darker(Theme.accent, 1.2) : (wifiRescanHover.hovered ? Theme.accent : Theme.text)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    scale: wifiRescanTap.pressed ? 0.85 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RotationAnimation on rotation {
                        from: 0; to: 360; 
                        duration: 750
                        running: wifiRescanProcess.running
                        loops: Animation.Infinite
                    }

                    HoverHandler { id: wifiRescanHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: wifiRescanTap
                        onTapped: {
                            if (!wifiRescanProcess.running) {
                                rescanIcon.rotation = 0
                                wifiRescanProcess.running = true
                            }
                        }
                    }
                }

                Rectangle {
                    width: 40; height: 22; radius: 11
                    color: root.wifiEnabled ? Theme.accent : Theme.surfaceHover
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        width: 16; height: 16; radius: 8
                        color: root.wifiEnabled ? Theme.background : Theme.subtext
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.wifiEnabled ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            root.wifiEnabled = !root.wifiEnabled
                            wifiToggleProcess.command = ["nmcli", "radio", "wifi", root.wifiEnabled ? "on" : "off"]
                            if (!wifiToggleProcess.running) wifiToggleProcess.running = true
                        }
                    }
                }
            }
        }

        // Active connection status
        Rectangle {
            visible: root.wifiEnabled && root.netSsid !== "" && root.netSsid !== "disconnected"
            width: parent.width; height: 44; radius: 8
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)

            Row {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                Text { 
                    text: {
                        if (root.netSignal > 80) return "󰤨"
                        if (root.netSignal > 60) return "󰤥"
                        if (root.netSignal > 40) return "󰤢"
                        if (root.netSignal > 20) return "󰤟"
                        return "󰤯"
                    }
                    color: Theme.accent; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter 
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: root.netSsid; color: Theme.text; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; width: 230 }
                    Text { text: "Connected"; color: Theme.accent; font.pixelSize: 10 }
                }
            }
        }

        // Available networks
        ListView {
            id: wifiListView
            width: parent.width
            height: Math.min(contentHeight, 140)
            visible: root.wifiEnabled && root.wifiNetworks.length > 0
            model: root.wifiNetworks
            clip: true
            spacing: 2
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: wifiListView.contentHeight > wifiListView.height + 2 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                interactive: true
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Theme.accent
                }
            }

            delegate: Rectangle {
                id: wifiDelegate
                required property var modelData
                property bool showPassword: root.passwordSsid === modelData.ssid

                width: parent ? parent.width - (wifiListView.ScrollBar.vertical.visible ? 10 : 0) : 0
                height: showPassword ? 88 : 34
                radius: 10
                clip: true
                color: root.connectingWifi === modelData.ssid
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                    : (netItemHover.hovered && !showPassword ? Theme.surfaceHover : "transparent")

                Behavior on height   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color    { ColorAnimation  { duration: 100 } }

                // ── Network row ────────────────────────────────────────────
                Rectangle {
                    id: netRow
                    width: parent.width
                    height: 34
                    color: "transparent"
                    radius: 10

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: {
                                if (modelData.signal > 80) return "󰤨"
                                if (modelData.signal > 60) return "󰤥"
                                if (modelData.signal > 40) return "󰤢"
                                if (modelData.signal > 20) return "󰤟"
                                return "󰤯"
                            }
                            color: modelData.signal > 20 ? Theme.accent : Theme.subtext
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: modelData.ssid
                                color: Theme.text; font.pixelSize: 12
                                elide: Text.ElideRight; width: Math.min(implicitWidth, 140)
                            }
                            Text {
                                text: modelData.security !== "" ? "󰌾" : ""
                                color: Theme.subtext; font.pixelSize: 11
                                visible: text !== ""
                            }
                        }
                    }

                    // Tap handler scoped ONLY to the network row
                    HoverHandler { id: netItemHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            let isSaved = root.savedNetworks.includes(modelData.ssid)
                            
                            // If secure AND we don't have it saved, ask for password
                            if (modelData.security !== "" && !isSaved) {
                                if (root.passwordSsid === modelData.ssid) {
                                    root.passwordSsid = ""
                                    root.passwordText = ""
                                    root.passwordVisible = false
                                } else {
                                    root.passwordSsid = modelData.ssid
                                    root.passwordText = ""
                                    root.passwordVisible = false
                                    pwField.text = ""
                                    Qt.callLater(() => pwField.forceActiveFocus())
                                }
                                return
                            }
                            
                            // Otherwise, connect immediately
                            root.connectingWifi = modelData.ssid
                            resetConnectingWifi.restart()
                            wifiConnectProcess.command = ["nmcli", "dev", "wifi", "connect", modelData.ssid]
                            if (!wifiConnectProcess.running) wifiConnectProcess.running = true
                        }
                    }
                }

                // ── Password row (slides in) ────────────────────────────────
                Item {
                    id: pwRow
                    anchors.top: netRow.bottom
                    anchors.topMargin: 2
                    width: parent.width
                    height: 50
                    opacity: wifiDelegate.showPassword ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {} // swallow
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        // Password field
                        Rectangle {
                            width: parent.width - 72
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 8
                            color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.10)
                            border.width: pwField.activeFocus ? 1 : 0
                            border.color: Theme.accent
                            Behavior on border.width { NumberAnimation { duration: 100 } }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 4

                                Item {
                                    width: parent.width - 28
                                    height: parent.height

                                    TextField {
                                        id: pwField
                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: root.passwordVisible ? TextInput.Normal : TextInput.Password
                                        color: Theme.text
                                        font.pixelSize: 12
                                        font.family: "Inter"
                                        
                                        placeholderText: "Password"
                                        placeholderTextColor: Theme.subtext
                                        
                                        background: Item {}
                                        selectionColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

                                        onTextChanged: root.passwordText = text
                                        onAccepted: connectBtn.doConnect()
                                        onVisibleChanged: if (visible && wifiDelegate.showPassword) forceActiveFocus()
                                        
                                        Keys.onEscapePressed: {
                                            root.passwordSsid = ""
                                            root.passwordText = ""
                                            root.passwordVisible = false
                                            text = ""
                                        }
                                    }
                                }

                                // Eye toggle
                                Rectangle {
                                    width: 24; height: 24
                                    color: "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: 1
                                        text: root.passwordVisible ? "󰛐" : "󰛑"
                                        font.pixelSize: 14
                                        color: eyeHover.hovered ? Theme.accent : Theme.subtext
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }
                                    HoverHandler { id: eyeHover; cursorShape: Qt.PointingHandCursor }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root.passwordVisible = !root.passwordVisible
                                            pwField.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }

                        // Connect button
                        Rectangle {
                            id: connectBtn
                            width: 62; height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 8
                            color: cbMouse.pressed ? Qt.darker(Theme.accent, 1.15) : (cbHover.hovered ? Qt.lighter(Theme.accent, 1.15) : Theme.accent)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            function doConnect() {
                                let ssid = wifiDelegate.modelData.ssid
                                let pass = root.passwordText
                                if (pass.length === 0) return
                                root.connectingWifi = ssid
                                resetConnectingWifi.restart()
                                wifiConnectWithPassProcess.command = [
                                    "nmcli", "dev", "wifi", "connect", ssid, "password", pass
                                ]
                                if (!wifiConnectWithPassProcess.running)
                                    wifiConnectWithPassProcess.running = true
                                pwField.text = ""
                                root.passwordText = ""
                                root.passwordSsid = ""
                                root.passwordVisible = false
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Connect"
                                font.pixelSize: 11; font.bold: true
                                color: Theme.background
                            }

                            HoverHandler { id: cbHover; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                id: cbMouse
                                anchors.fill: parent
                                onClicked: connectBtn.doConnect()
                            }
                        }
                    }
                }
            }
        }

        // Disabled state
        Item {
            visible: !root.wifiEnabled
            width: parent.width; height: 40
            Text {
                anchors.centerIn: parent
                text: "Wi-Fi is turned off"
                color: Theme.subtext
                font.pixelSize: 12
                font.bold: true
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.12) }

    // Bluetooth section
    Column {
        width: parent.width
        spacing: 8

        Item {
            width: parent.width
            height: 28

            Text {
                text: "󰂯  Bluetooth"
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 40; height: 22; radius: 11
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: root.btEnabled ? Theme.accent : Theme.surfaceHover
                Behavior on color { ColorAnimation { duration: 200 } }

                Rectangle {
                    width: 16; height: 16; radius: 8
                    color: root.btEnabled ? Theme.background : Theme.subtext
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.btEnabled ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        root.btEnabled = !root.btEnabled
                        btToggleProcess.command = ["bluetoothctl", "power", root.btEnabled ? "on" : "off"]
                        if (!btToggleProcess.running) btToggleProcess.running = true
                    }
                }
            }
        }

        ListView {
            id: btListView
            width: parent.width
            height: Math.min(contentHeight, 140)
            visible: root.btEnabled && root.visibleBtDevices.length > 0
            model: root.visibleBtDevices
            clip: true; spacing: 2
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: btListView.contentHeight > btListView.height + 2 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                interactive: true
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Theme.accent
                }
            }

            delegate: Rectangle {
                required property var modelData
                width: parent ? parent.width - (btListView.ScrollBar.vertical.visible ? 10 : 0) : 0
                height: 44; radius: 8
                color: root.connectingBt === modelData.mac ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : (btItemHover.hovered ? Theme.surfaceHover : "transparent")
                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10

                    Text {
                        text: {
                            if (!modelData || !modelData.name) return "󰂯"
                            let n = modelData.name.toLowerCase()
                            if (n.includes("buds") || n.includes("air") || n.includes("xm") || n.includes("headp")) return "󰋋"
                            if (n.includes("key")) return "󰌌"
                            if (n.includes("mouse") || n.includes("master") || n.includes("trackpad")) return "󰍽"
                            return "󰂯"
                        }
                        color: modelData.connected === "1" ? Theme.accent : Theme.subtext
                        font.pixelSize: 18
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        
                        Row {
                            spacing: 8
                            Text {
                                text: modelData.name || "Unknown"
                                color: Theme.text; font.pixelSize: 12; font.bold: true
                                elide: Text.ElideRight; width: Math.min(implicitWidth, 130)
                            }
                            
                            Rectangle {
                                visible: modelData.battery !== "--" && modelData.battery !== ""
                                width: btBatRow.implicitWidth + 8; height: 16; radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)

                                Row {
                                    id: btBatRow; anchors.centerIn: parent; spacing: 3
                                    Text { text: "󰥉"; color: Theme.accent; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: modelData.battery + "%"; color: Theme.text; font.pixelSize: 9; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                        
                        Text {
                            text: modelData.connected === "1" ? "Connected" : (modelData.paired === "1" ? "Paired" : "Available")
                            color: modelData.connected === "1" ? Theme.accent : Theme.subtext
                            font.pixelSize: 10
                        }
                    }
                }

                HoverHandler { id: btItemHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        root.connectingBt = modelData.mac
                        resetConnectingBt.restart()
                        let action = "connect"
                        if (modelData.connected === "1") action = "disconnect"
                        else if (modelData.paired === "0") action = "pair"
                        if (action === "pair") {
                            btActionProcess.command = ["bash", "-c", "bluetoothctl pair " + modelData.mac + " && bluetoothctl connect " + modelData.mac]
                        } else {
                            btActionProcess.command = ["bluetoothctl", action, modelData.mac]
                        }
                        if (!btActionProcess.running) btActionProcess.running = true
                        Qt.callLater(() => { if (!btListProcess.running) btListProcess.running = true })
                    }
                }
            }
        }

        Rectangle {
            visible: root.btEnabled
            width: parent.width; height: 30; radius: 8
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.15)

            scale: scanTap.pressed ? 0.96 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            Text { 
                anchors.centerIn: parent
                text: root.isScanningBt ? "󰑐  Scanning..." : "󰑐  Scan for devices"
                color: scanHover.hovered ? Theme.accent : Theme.text
                font.pixelSize: 11; font.bold: true 
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            HoverHandler { id: scanHover; cursorShape: Qt.PointingHandCursor }
            
            Rectangle { 
                anchors.fill: parent; radius: 8
                color: Theme.surfaceHover
                opacity: scanHover.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation{ duration:150 } } 
                z: -1
            }
            
            TapHandler {
                id: scanTap
                onTapped: {
                    root.isScanningBt = true
                    btScanProcess.command = ["bash", "-c", "bluetoothctl --timeout 5 scan on"]
                    if (!btScanProcess.running) btScanProcess.running = true
                }
            }
        }

        Item {
            visible: !root.btEnabled
            width: parent.width; height: 40
            Text {
                anchors.centerIn: parent
                text: "Bluetooth is turned off"
                color: Theme.subtext
                font.pixelSize: 12
                font.bold: true
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.12) }

    // Battery and power section
    Column {
        width: parent.width
        spacing: 10

        Text { text: "󰁹  Battery"; color: Theme.text; font.pixelSize: 14; font.bold: true }

        Row {
            width: parent.width; spacing: 12

            Text {
                text: root.batLevel + "%"
                color: root.batLevel < 20 ? Theme.danger : Theme.text
                font.pixelSize: 28; font.bold: true
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: root.batStatus
                    color: root.batStatus === "Charging" ? Theme.accent : Theme.subtext
                    font.pixelSize: 12; font.bold: true
                }
                Text {
                    text: root.batTimeLeft !== "" ? "~" + root.batTimeLeft + " left" : ""
                    color: Theme.subtext; font.pixelSize: 11
                    visible: text !== ""
                }
            }
        }

        Row {
            spacing: 4
            Repeater {
                model: [
                    { label: "Saver", value: "power-saver", icon: "󰌪" },
                    { label: "Balanced", value: "balanced", icon: "󰗑" },
                    { label: "Performance", value: "performance", icon: "󱐋" }
                ]
                Rectangle {
                    required property var modelData
                    width: (parent.parent.width - 8) / 3
                    height: 30; radius: 8
                    
                    color: root.powerProfile === modelData.value ? Theme.accent : (profileHover.hovered ? Qt.lighter(Theme.surfaceHover, 1.3) : Theme.surfaceHover)
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text {
                            text: modelData.icon; font.pixelSize: 13
                            color: root.powerProfile === modelData.value ? Theme.background : Theme.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.label; font.pixelSize: 11; font.bold: true
                            color: root.powerProfile === modelData.value ? Theme.background : Theme.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: profileHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            root.powerProfile = modelData.value
                            if (profileProcess.running) profileProcess.running = false; 
                            profileProcess.command = ["bash", "-c", "powerprofilesctl set " + modelData.value + " > /dev/null 2>&1"]
                            profileProcess.running = true
                        }
                    }
                }
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.12) }

    // --- SYSTEM SLIDERS ---
    Column {
        width: parent.width
        spacing: 12

        // Section Title
        Item {
            width: parent.width
            height: 28
            Text {
                text: "󰕾  System Sliders"
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Volume Slider
        Item {
            width: parent.width
            height: 36
            property bool isHovered: volDragArea.containsMouse || volDragArea.pressed

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.surfaceHover 
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: volHead.x + volHead.width 
                radius: height / 2 
                color: Theme.accent
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Rectangle {
                id: volHead
                width: parent.height 
                height: parent.height
                radius: width / 2
                color: Theme.text
                
                x: (Math.min(root.volLevel, 100) / 100) * (parent.width - width)
                Behavior on x { 
                    enabled: !volDragArea.pressed
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad } 
                }

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (root.volLevel <= 0) return "󰖁" 
                        if (root.volLevel < 33) return "󰕿" 
                        if (root.volLevel < 66) return "󰖀" 
                        return "󰕾" 
                    }
                    color: Theme.background
                    font.pixelSize: 18
                    
                    opacity: parent.parent.isHovered ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.volLevel
                    color: Theme.background
                    font.pixelSize: 13
                    font.bold: true
                    
                    opacity: parent.parent.isHovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                }
            }

            MouseArea {
                id: volDragArea
                anchors.fill: parent
                hoverEnabled: true
                
                function updateValue(mouse) {
                    let headHalf = volHead.width / 2;
                    let trackWidth = width - volHead.width;
                    let rawX = mouse.x - headHalf;
                    let pct = Math.max(0, Math.min(1, rawX / trackWidth));
                    let val = Math.round(pct * 100);
                    
                    root.volLevel = val;
                    if (Pipewire.defaultAudioSink) {
                        Pipewire.defaultAudioSink.audio.volume = val / 100;
                    }
                }
                
                onPressed: (mouse) => updateValue(mouse)
                onPositionChanged: (mouse) => { if (pressed) updateValue(mouse) }
            }
        }

        // Brightness Slider
        Item {
            width: parent.width
            height: 36
            property bool isHovered: briDragArea.containsMouse || briDragArea.pressed

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.surfaceHover 
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: briHead.x + briHead.width 
                radius: height / 2 
                color: Theme.accent
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Rectangle {
                id: briHead
                width: parent.height 
                height: parent.height
                radius: width / 2
                color: Theme.text
                
                x: (Math.min(root.briLevel, 100) / 100) * (parent.width - width)
                Behavior on x { 
                    enabled: !briDragArea.pressed
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad } 
                }

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (root.briLevel < 33) return "󰃞" 
                        if (root.briLevel < 66) return "󰃟" 
                        return "󰃠" 
                    }
                    color: Theme.background
                    font.pixelSize: 14
                    
                    opacity: parent.parent.isHovered ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.briLevel
                    color: Theme.background
                    font.pixelSize: 13
                    font.bold: true
                    
                    opacity: parent.parent.isHovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                }
            }

            MouseArea {
                id: briDragArea
                anchors.fill: parent
                hoverEnabled: true
                
                function updateValue(mouse) {
                    let headHalf = briHead.width / 2;
                    let trackWidth = width - briHead.width;
                    let rawX = mouse.x - headHalf;
                    let pct = Math.max(0, Math.min(1, rawX / trackWidth));
                    let val = Math.round(pct * 100);
                    
                    root.briLevel = val;
                    briSetProcess.command = ["brightnessctl", "s", val + "%"];
                    if (!briSetProcess.running) briSetProcess.running = true;
                }
                
                onPressed: (mouse) => updateValue(mouse)
                onPositionChanged: (mouse) => { if (pressed) updateValue(mouse) }
            }
        }
    }
}