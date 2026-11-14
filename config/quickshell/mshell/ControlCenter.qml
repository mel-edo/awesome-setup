import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "."

Column {
    id: root
    spacing: 16
    property bool isOpen: false
    property QtObject parentWindow: null
    property string netSsid: ""
    property int netSignal: 0
    property bool btConnected: false
    property bool vpnConnected: false
    property string vpnName: ""
    property int batLevel: 100
    property string batStatus: "Discharging"
    property bool wifiEnabled: true
    property bool btEnabled: true
    property var wifiNetworks: []
    property var savedNetworks: []
    property var btDevices: []
    property string powerProfile: "balanced"
    property string connectingWifi: ""
    property string connectingBt: ""
    property string passwordSsid: ""
    property string passwordText: ""
    property bool passwordVisible: false
    property bool isScanningBt: false
    property var visibleBtDevices: btDevices.filter(d => isScanningBt || d.paired === "1" || d.connected === "1")
    property string activeOrConnectingSsid: root.connectingWifi !== "" ? root.connectingWifi : (root.netSsid !== "disconnected" ? root.netSsid : "")
    property bool isWifiConnecting: root.connectingWifi !== ""
    signal requestNetworkRefresh()

    function startWifiTimeout() {
        resetConnectingWifiTimer.restart()
    }

    function stopWifiTimeout() {
        resetConnectingWifiTimer.stop()
    }

    function connectWifi(ssid) {
        if (root.isWifiConnecting) return;
        root.connectingWifi = ssid;
        root.wifiNetworks = root.wifiNetworks.filter(n => n.ssid !== ssid);
        root.startWifiTimeout();
        wifiActionProcess.command = [
            Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/watchers/wifi_control.sh",
            "connect",
            ssid
        ];
        if (!wifiActionProcess.running) wifiActionProcess.running = true;
    }

    function connectWifiWithPassword(ssid, pass) {
        if (root.isWifiConnecting) return;
        root.connectingWifi = ssid;
        root.wifiNetworks = root.wifiNetworks.filter(n => n.ssid !== ssid);
        root.startWifiTimeout();
        wifiActionProcess.command = [
            Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/watchers/wifi_control.sh",
            "connect_pass",
            ssid,
            pass
        ];
        if (!wifiActionProcess.running) wifiActionProcess.running = true;
    }

    function disconnectWifi() {
        wifiDisconnectProcess.command = [
            Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/watchers/wifi_control.sh",
            "disconnect"
        ];
        if (!wifiDisconnectProcess.running) wifiDisconnectProcess.running = true;
    }

    property int volLevel: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) : 50
    property int briLevel: 50
    property bool isDraggingSlider: volDragArea.pressed || briDragArea.pressed
    onIsDraggingSliderChanged: SharedState.isSuppressingOsd = isDraggingSlider
    
    Timer {
        id: resetConnectingWifiTimer
        interval: 20000
        onTriggered: {
            console.log("[ControlCenter] Wi-Fi connection timed out")
            root.connectingWifi = ""
            root.requestNetworkRefresh()
            if (!wifiListProcess.running) wifiListProcess.running = true
        }
    }
    Timer { id: resetConnectingBt; interval: 3000; onTriggered: root.connectingBt = "" }

    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() {
            if (!root.isDraggingSlider && Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                root.volLevel = Math.round(Pipewire.defaultAudioSink.audio.volume * 100);
            }
        }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            if (!root.isDraggingSlider && Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                root.volLevel = Math.round(Pipewire.defaultAudioSink.audio.volume * 100);
            }
        }
    }

    property string batTimeLeft: {
        let secs = UPower.displayDevice.state === UPowerDeviceState.Charging
            ? UPower.displayDevice.timeToFull
            : UPower.displayDevice.timeToEmpty
        if (!secs || secs <= 0) return ""
        let mins = secs / 60
        if (mins < 60) return Math.round(mins) + " minutes"
        return (mins / 60).toFixed(1) + " hours"
    }

    Process {
        id: syncWifiState
        command: ["bash", "-c", "nmcli -t radio wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifiEnabled = (text.trim() === "enabled") }
    }

    Process {
        id: syncBtState
        command: ["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'true' || echo 'false'"]
        stdout: StdioCollector { onStreamFinished: root.btEnabled = (text.trim() === "true") }
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
            if (!running) {
                rescanIcon.rotation = 0
                if (!wifiListProcess.running) wifiListProcess.running = true
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
                    if (parts.length >= 3 && parts[0] !== "" && parts[0] !== root.activeOrConnectingSsid && parts[0] !== root.netSsid && parts[0] !== root.connectingWifi) {
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

    // Toggles and Actions
    Process { id: wifiToggleProcess }
    Process { id: btToggleProcess }
    Process {
        id: wifiActionProcess
        stdout: StdioCollector {
            onStreamFinished: console.log("[ControlCenter] wifiAction: " + text.trim())
        }
        onExited: (exitCode) => {
            console.log("[ControlCenter] wifiAction exited: " + exitCode)
            if (exitCode === 0 && root.connectingWifi !== "") {
                root.netSsid = root.connectingWifi
            }
            root.connectingWifi = ""
            root.stopWifiTimeout()
            root.requestNetworkRefresh()
            if (!savedWifiFetchProcess.running) savedWifiFetchProcess.running = true
            if (!wifiListProcess.running) wifiListProcess.running = true
        }
    }
    Process {
        id: wifiDisconnectProcess
        stdout: StdioCollector {
            onStreamFinished: console.log("[ControlCenter] wifiDisconnect: " + text.trim())
        }
        onExited: (exitCode) => {
            console.log("[ControlCenter] wifiDisconnect exited: " + exitCode)
            root.netSsid = ""
            root.connectingWifi = ""
            root.stopWifiTimeout()
            root.requestNetworkRefresh()
            if (!wifiListProcess.running) wifiListProcess.running = true
        }
    }
    Process { id: btActionProcess }
    Process { id: btScanProcess }
    Process { id: profileProcess }
    Process { id: volSetProcess }
    Process { id: briSetProcess }

    Timer { interval: 10000; running: root.isOpen; repeat: true; onTriggered: { if (!wifiListProcess.running) wifiListProcess.running = true; if (!savedWifiFetchProcess.running) savedWifiFetchProcess.running = true } }
    Timer { interval: 5000; running: root.isOpen; repeat: true; onTriggered: { if (!btListProcess.running) btListProcess.running = true } }

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
            syncWifiState.running = true
            syncBtState.running = true
            if (!savedWifiFetchProcess.running) savedWifiFetchProcess.running = true
            if (!wifiListProcess.running) wifiListProcess.running = true
            if (!btListProcess.running) btListProcess.running = true
            if (!profileFetchProcess.running) profileFetchProcess.running = true
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
                        onRunningChanged: {
                            if (!running) rescanIcon.rotation = 0
                        }
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

        // Active or Connecting Wi-Fi card
        Rectangle {
            id: activeNetCard
            visible: root.wifiEnabled && (root.activeOrConnectingSsid !== "")
            width: parent.width; height: 46; radius: 10
            color: root.isWifiConnecting
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
            border.width: 1
            border.color: root.isWifiConnecting
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Row {
                anchors.left: parent.left
                anchors.right: disconnectBtn.visible ? disconnectBtn.left : parent.right
                anchors.rightMargin: disconnectBtn.visible ? 8 : 12
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Item {
                    width: 22; height: 22
                    anchors.verticalCenter: parent.verticalCenter

                    // Connecting spinner
                    Text {
                        visible: root.isWifiConnecting
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: Theme.accent
                        font.pixelSize: 18

                        RotationAnimation on rotation {
                            from: 0; to: 360; duration: 800
                            running: root.isWifiConnecting
                            loops: Animation.Infinite
                        }
                    }

                    // Static upright Wi-Fi signal icon
                    Text {
                        visible: !root.isWifiConnecting
                        anchors.centerIn: parent
                        text: {
                            if (root.netSignal > 80) return "󰤨";
                            if (root.netSignal > 60) return "󰤥";
                            if (root.netSignal > 40) return "󰤢";
                            if (root.netSignal > 20) return "󰤟";
                            return "󰤯";
                        }
                        color: Theme.accent
                        font.pixelSize: 18
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: root.activeOrConnectingSsid
                        color: Theme.text
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                        width: disconnectBtn.visible ? 150 : 220
                    }
                    Text {
                        text: root.isWifiConnecting ? "Connecting..." : "Connected"
                        color: Theme.accent
                        font.pixelSize: 10
                        font.bold: root.isWifiConnecting
                    }
                }
            }

            Rectangle {
                id: disconnectBtn
                visible: !root.isWifiConnecting && root.netSsid !== "" && root.netSsid !== "disconnected"
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                width: dcRow.implicitWidth + 14
                radius: 12
                color: dcTap.pressed ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.25)
                     : (dcHover.hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.18)
                     : Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.12))
                border.width: 1
                border.color: dcHover.hovered
                     ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.40)
                     : Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.20)

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    id: dcRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰅖"
                        color: dcHover.hovered ? Theme.danger : Theme.subtext
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Disconnect"
                        color: dcHover.hovered ? Theme.danger : Theme.text
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: dcHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: dcTap
                    onTapped: root.disconnectWifi()
                }
            }
        }

        // Dedicated VPN Status card
        Rectangle {
            visible: root.vpnConnected
            width: parent.width; height: 44; radius: 10
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
            border.width: 1
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)

            Row {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                Text {
                    text: "󰖂"
                    color: Theme.accent
                    font.pixelSize: 18
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: root.vpnName ? root.vpnName : "VPN Tunnel"
                        color: Theme.text
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                        width: 220
                    }
                    Text {
                        text: "VPN Connected"
                        color: Theme.accent
                        font.pixelSize: 10
                    }
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
                height: showPassword ? 88 : 36
                radius: 8
                clip: true
                color: root.connectingWifi === modelData.ssid
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                    : (netItemHover.hovered && !showPassword ? Theme.surfaceHover : "transparent")

                Behavior on height   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color    { ColorAnimation  { duration: 100 } }

                // Network row
                Rectangle {
                    id: netRow
                    width: parent.width
                    height: 36
                    color: "transparent"
                    radius: 8

                    Row {
                        anchors.left: parent.left
                        anchors.right: savedBadge.visible ? savedBadge.left : parent.right
                        anchors.rightMargin: savedBadge.visible ? 8 : 10
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            text: {
                                if (modelData.signal > 80) return "󰤨";
                                if (modelData.signal > 60) return "󰤥";
                                if (modelData.signal > 40) return "󰤢";
                                if (modelData.signal > 20) return "󰤟";
                                return "󰤯";
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

                    Rectangle {
                        id: savedBadge
                        visible: root.savedNetworks.includes(modelData.ssid)
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 16
                        width: savedLabel.implicitWidth + 8
                        radius: 8
                        color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.12)
                        Text {
                            id: savedLabel
                            anchors.centerIn: parent
                            text: "Saved"
                            color: Theme.subtext
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }

                    HoverHandler { id: netItemHover; cursorShape: root.isWifiConnecting ? Qt.ForbiddenCursor : Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.isWifiConnecting ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (root.isWifiConnecting) return;

                            let isSaved = root.savedNetworks.includes(modelData.ssid)
                            
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
                            
                            root.connectWifi(modelData.ssid)
                        }
                    }
                }

                // Password row
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
                        onClicked: {}
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
                                root.connectWifiWithPassword(ssid, pass)
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

        // Scanning / empty state
        Item {
            visible: root.wifiEnabled && root.wifiNetworks.length === 0 && !root.isWifiConnecting
            width: parent.width; height: 32
            Row {
                anchors.centerIn: parent
                spacing: 6
                Item {
                    width: 14; height: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        visible: wifiRescanProcess.running
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: Theme.subtext
                        font.pixelSize: 12
                        RotationAnimation on rotation {
                            from: 0; to: 360; duration: 750
                            running: wifiRescanProcess.running
                            loops: Animation.Infinite
                        }
                    }

                    Text {
                        visible: !wifiRescanProcess.running
                        anchors.centerIn: parent
                        text: "󰤮"
                        color: Theme.subtext
                        font.pixelSize: 12
                    }
                }
                Text {
                    text: wifiRescanProcess.running ? "Scanning for networks..." : "No networks found"
                    color: Theme.subtext
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
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

                Item {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10

                    Text {
                        id: btTypeIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
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
                    }

                    Rectangle {
                        id: btBatBadge
                        visible: modelData.battery !== "--" && modelData.battery !== ""
                        width: btBatRow.implicitWidth + 8; height: 16; radius: 8
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)

                        Row {
                            id: btBatRow; anchors.centerIn: parent; spacing: 3
                            Text { text: "󰥉"; color: Theme.accent; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.battery + "%"; color: Theme.text; font.pixelSize: 9; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    Column {
                        anchors.left: btTypeIcon.right
                        anchors.leftMargin: 10
                        anchors.right: btBatBadge.visible ? btBatBadge.left : parent.right
                        anchors.rightMargin: btBatBadge.visible ? 8 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            id: btNameText
                            text: modelData.name || "Unknown"
                            color: Theme.text; font.pixelSize: 12; font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
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

    // System Sliders
    Column {
        width: parent.width
        spacing: 12

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
                    NumberAnimation { duration: 100; easing.type: Easing.OutQuad } 
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
                    let rawVal = pct * 100;
                    let nearest5 = Math.round(rawVal / 5) * 5;
                    let val = Math.abs(rawVal - nearest5) <= 1.5 ? nearest5 : Math.round(rawVal);
                    
                    root.volLevel = val;
                    if (Pipewire.defaultAudioSink) {
                        Pipewire.defaultAudioSink.audio.volume = val / 100;
                    }
                }
                
                onPressed: (mouse) => updateValue(mouse)
                onPositionChanged: (mouse) => { if (pressed) updateValue(mouse) }
            }
        }

        // Brightness slider
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
                    NumberAnimation { duration: 100; easing.type: Easing.OutQuad } 
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
                    
                    let rawVal = pct * 100;
                    let nearest5 = Math.round(rawVal / 5) * 5;
                    let val = Math.abs(rawVal - nearest5) <= 1.5 ? nearest5 : Math.round(rawVal);
                    
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