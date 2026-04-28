import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

WlrLayershell {
    id: launcherRoot
    required property var screen
    
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    layer: WlrLayer.Overlay
    keyboardFocus: WlrKeyboardFocus.OnDemand 
    color: "transparent"
    visible: isOpen || openAnim.running || closeAnim.running || openDelayTimer.running
    property var allApps: []
    property bool isOpen: false
    
    ListModel { id: appModel }

    Process {
        id: appFetchProcess
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/app_fetcher.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    launcherRoot.allApps = JSON.parse(text.trim())
                    filterApps("") // Populate initial list
                } catch(e) { console.log("Failed to parse apps: " + e) }
            }
        }
    }

    Process { id: launchProcess }

    // Fuzzy search filter
    function filterApps(query) {
        appModel.clear()
        if (allApps.length === 0) return

        let results = []
        if (query === "") {
            results = allApps
        } else {
            let fuzzyPattern = query.toLowerCase().split('').join('.*')
            let regex = new RegExp(fuzzyPattern, "i")
            
            results = allApps.filter(app => regex.test(app.name.toLowerCase()))
            
            results.sort((a, b) => {
                let aStarts = a.name.toLowerCase().startsWith(query.toLowerCase()) ? -1 : 1
                let bStarts = b.name.toLowerCase().startsWith(query.toLowerCase()) ? -1 : 1
                return aStarts - bStarts
            })
        }

        for (let i = 0; i < Math.min(results.length, 8); i++) {
            appModel.append(results[i])
        }

        if (launcherRoot.isOpen) {
            droplet.height = 60 + (query === "" ? 0 : (appModel.count * 48) + 1)
        }
    }

    function launchTopApp() {
        if (appModel.count > 0) {
            launchProcess.command = ["hyprctl", "dispatch", "exec", appModel.get(0).exec]
            if (!launchProcess.running) launchProcess.running = true
            shellRoot.launcherOpen = false
        }
    }

    Timer {
        id: openDelayTimer
        interval: 30
        onTriggered: openAnim.restart()
    }

    onIsOpenChanged: {
        if (isOpen) {
            closeAnim.stop()
            openDelayTimer.restart() // Starts the delay timer instead of the animation directly
        } else {
            openDelayTimer.stop()
            openAnim.stop()
            closeAnim.restart()
        }
    }

    // Background closer
    MouseArea {
        anchors.fill: parent
        onClicked: if (shellRoot.launcherOpen) shellRoot.launcherOpen = false
    }

    Rectangle {
        id: droplet
        
        x: (parent.width - width) / 2
        y: -100
        width: 40; height: 40; radius: 20
        
        color: Theme.surface
        border.width: 1
        border.color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2)
        clip: true
        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }

        Item {
            id: searchContent
            width: 600
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: 0

            Column {
                anchors.fill: parent
                
                // Search input
                Item {
                    width: parent.width
                    height: 60

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 16

                        Text { 
                            id: searchIcon
                            text: ""
                            color: Theme.accent
                            font.pixelSize: 20
                            anchors.verticalCenter: parent.verticalCenter 
                        }

                        TextField {
                            id: searchInput
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - searchIcon.width - 16
                            
                            placeholderText: "Search apps..."
                            color: Theme.text
                            placeholderTextColor: Theme.subtext
                            font.pixelSize: 18
                            background: Item {} 
                            
                            onTextChanged: launcherRoot.filterApps(text)
                            
                            Keys.onReturnPressed: launcherRoot.launchTopApp()
                            Keys.onEscapePressed: shellRoot.launcherOpen = false
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.15); visible: appModel.count > 0 && searchInput.text !== "" }

                // Application list
                ListView {
                    id: appList
                    width: parent.width
                    height: contentHeight
                    model: appModel
                    visible: searchInput.text !== "" 
                    clip: true
                    
                    delegate: Rectangle {
                        width: parent.width
                        height: 48
                        color: appHover.hovered ? Theme.surfaceHover : "transparent"

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20; spacing: 12
                            
                            Image {
                                source: model.icon.startsWith("/") ? "file://" + model.icon : "image://icon/" + model.icon
                                width: 24; height: 24; sourceSize: Qt.size(24, 24)
                                anchors.verticalCenter: parent.verticalCenter
                                onStatusChanged: if (status === Image.Error) source = "" 
                            }
                            
                            Text {
                                text: model.name
                                color: Theme.text
                                font.pixelSize: 14
                                font.bold: index === 0 
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        HoverHandler { id: appHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                launchProcess.command = ["hyprctl", "dispatch", "exec", model.exec]
                                if (!launchProcess.running) launchProcess.running = true
                                shellRoot.launcherOpen = false
                            }
                        }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: openAnim
        
        NumberAnimation { 
            target: droplet; 
            property: "y"; 
            to: (launcherRoot.height * 0.20) - 30; 
            duration: 300; 
            easing.type: Easing.OutExpo 
        }
        
        ParallelAnimation {
            NumberAnimation { target: droplet; property: "width"; to: 600; duration: 300; easing.type: Easing.OutExpo }
            NumberAnimation { target: droplet; property: "height"; to: 60; duration: 300; easing.type: Easing.OutExpo }
            NumberAnimation { target: droplet; property: "radius"; to: 16; duration: 300; easing.type: Easing.OutExpo }
            NumberAnimation { target: searchContent; property: "opacity"; to: 1; duration: 250 }
        }
        
        ScriptAction { script: searchInput.forceActiveFocus() }
    }

    SequentialAnimation {
        id: closeAnim
        
        ParallelAnimation {
            NumberAnimation { target: searchContent; property: "opacity"; to: 0; duration: 150 }
            NumberAnimation { target: droplet; property: "width"; to: 40; duration: 250; easing.type: Easing.OutExpo }
            NumberAnimation { target: droplet; property: "height"; to: 40; duration: 250; easing.type: Easing.OutExpo }
            NumberAnimation { target: droplet; property: "radius"; to: 20; duration: 250; easing.type: Easing.OutExpo }
        }
        
        NumberAnimation { target: droplet; property: "y"; to: -100; duration: 250; easing.type: Easing.InExpo }
        
        ScriptAction { script: searchInput.text = "" }
    }
}