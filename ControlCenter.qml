import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

Column {
    id: root
    spacing: 16
    property bool isOpen: false
    property QtObject parentWindow: null
    property string netSsid: ""
    property bool btConnected: false
    property int batLevel: 100
    property string batStatus: "Discharging"
    property bool wifiEnabled: true
    property bool btEnabled: true
    property var wifiNetworks: []
    property var btDevices: []
    property string powerProfile: "balanced"
    property string batTimeLeft: ""

    Process {
        id: wifiListProcess
        command: [Quickshell.env("HOME") + "/.config/quickshell-new/mshell/scripts/watchers/wifi_list.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n").filter(x => x !== "")
                let nets = []
                for (let line of lines) {
                    let parts = line.split(":")
                    if (parts.length >= 3 && parts[0] !== "") {
                        nets.push({ ssid: parts[0], signal: parseInt(parts[1]) || 0, security: parts[2] || "" })
                    }
                }
                root.wifiNetworks = nets
            }
        }
    }

    Process {
        id: btListProcess
        command: [Quickshell.env("HOME") + "/.config/quickshell-new/mshell/scripts/watchers/bt_list.sh"]
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
        command: [Quickshell.env("HOME") + "/.config/quickshell-new/mshell/scripts/watchers/power_profile.sh"]
        stdout: StdioCollector { onStreamFinished: root.powerProfile = text.trim() }
    }

    Process {
        id: batTimeProcess
        command: ["bash", "-c", "upower -i /org/freedesktop/UPower/devices/battery_BAT1 2>/dev/null | grep 'time to' | awk '{print $4, $5}'"]
        stdout: StdioCollector { onStreamFinished: root.batTimeLeft = text.trim() }
    }

    // Toggles
    Process { id: wifiToggleProcess }
    Process { id: btToggleProcess }
    Process { id: wifiConnectProcess }
    Process { id: btActionProcess }
    Process { id: btScanProcess }
    Process { id: profileProcess }

    // Smart Refreshers
    Timer { interval: 10000; running: root.isOpen; repeat: true; onTriggered: wifiListProcess.running = true }
    Timer { interval: 5000; running: root.isOpen; repeat: true; onTriggered: { btListProcess.running = true; batTimeProcess.running = true } }

    onIsOpenChanged: {
        if (isOpen) {
            wifiListProcess.running = true
            btListProcess.running = true
            profileFetchProcess.running = true
            batTimeProcess.running = true
        }
    }

    // ─────────── SECTION 1: NETWORK ───────────
    Column {
        width: parent.width
        spacing: 8

        Item {
            width: parent.width
            height: 28

            Text {
                text: "󰤨    Network"
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
                        wifiToggleProcess.running = true
                    }
                }
            }
        }

        // Active Connection Highlight
        Rectangle {
            visible: root.wifiEnabled && root.netSsid !== "" && root.netSsid !== "disconnected"
            width: parent.width; height: 44; radius: 8
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)

            Row {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                Text { text: "󰤨"; color: Theme.accent; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: root.netSsid; color: Theme.text; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; width: 230 }
                    Text { text: "Connected"; color: Theme.accent; font.pixelSize: 10 }
                }
            }
        }

        // Available Networks List
        ListView {
            width: parent.width
            height: Math.min(contentHeight, 140)
            visible: root.wifiEnabled && root.wifiNetworks.length > 0
            model: root.wifiNetworks
            clip: true
            spacing: 2
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                interactive: true
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Theme.accent
                }
            }

            delegate: Rectangle {
                required property var modelData
                width: parent ? parent.width : 0
                height: 34; radius: 8
                color: netItemHover.hovered ? Theme.surfaceHover : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        spacing: 2; anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: 3; height: 5 + index * 3; radius: 1
                                anchors.bottom: parent ? parent.bottom : undefined
                                color: (modelData.signal / 25) > index ? Theme.accent : Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.3)
                            }
                        }
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

                HoverHandler { id: netItemHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        wifiConnectProcess.command = ["nmcli", "dev", "wifi", "connect", modelData.ssid]
                        wifiConnectProcess.running = true
                    }
                }
            }
        }

        // Wi-Fi Off State
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

    // ─────────── SECTION 2: BLUETOOTH ───────────
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
                        btToggleProcess.running = true
                    }
                }
            }
        }

        ListView {
            width: parent.width
            height: Math.min(contentHeight, 140)
            visible: root.btEnabled && root.btDevices.length > 0
            model: root.btDevices
            clip: true; spacing: 2
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                interactive: true
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Theme.accent
                }
            }

            delegate: Rectangle {
                required property var modelData
                width: parent ? parent.width : 0
                height: 44; radius: 8
                color: btItemHover.hovered ? Theme.surfaceHover : "transparent"
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
                        let action = "connect"
                        if (modelData.connected === "1") action = "disconnect"
                        else if (modelData.paired === "0") action = "pair"
                        if (action === "pair") {
                            btActionProcess.command = ["bash", "-c", "bluetoothctl pair " + modelData.mac + " && bluetoothctl connect " + modelData.mac]
                        } else {
                            btActionProcess.command = ["bluetoothctl", action, modelData.mac]
                        }
                        btActionProcess.running = true
                        Qt.callLater(() => { btListProcess.running = true })
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
                text: "󰑐  Scan for devices"
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
                    btScanProcess.command = ["bash", "-c", "bluetoothctl --timeout 5 scan on"]
                    btScanProcess.running = true
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

    // ─────────── SECTION 3: BATTERY ───────────
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
                    color: root.powerProfile === modelData.value ? Theme.accent : Theme.surfaceHover
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

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            root.powerProfile = modelData.value
                            profileProcess.command = ["powerprofilesctl", "set", modelData.value]
                            profileProcess.running = true
                        }
                    }
                }
            }
        }
    }
}