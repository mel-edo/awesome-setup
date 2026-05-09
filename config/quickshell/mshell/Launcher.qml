import QtQuick
import QtQuick.Controls
import QtQuick.Window
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
    property bool isFullyOpen: false
    
    signal requestClose()

    ListModel { id: appModel }
    Process { id: launchProcess }
    Process { id: recordProcess }

    function filterApps(query) {
        appModel.clear()
        if (allApps.length === 0) return

        let results = []
        if (query === "") {
            results = allApps 
        } else {
            let fuzzyPattern = query.toLowerCase().split('').join('.*')
            let regex = new RegExp(fuzzyPattern, "i")
            results = allApps.map((app, index) => {
                app._cacheRank = index; 
                return app;
            }).filter(app => {
                let nameStr = (app.name || "").toLowerCase()
                let execStr = (app.exec || "").toLowerCase()
                return regex.test(nameStr) || regex.test(execStr)
            })
            results.sort((a, b) => {
                let queryLower = query.toLowerCase()
                let aStarts = (a.name || "").toLowerCase().startsWith(queryLower) ? 0 : 1
                let bStarts = (b.name || "").toLowerCase().startsWith(queryLower) ? 0 : 1
                if (aStarts !== bStarts) {
                    return aStarts - bStarts 
                }
                return a._cacheRank - b._cacheRank
            })
        }

        for (let i = 0; i < results.length; i++) {
            appModel.append(results[i])
        }

        if (isFullyOpen) {
            droplet.height = searchContent.height
        }
    }

    function launchSelectedApp() {
        if (appModel.count > 0 && appList.currentIndex >= 0 && appList.currentIndex < appModel.count) {
            let app = appModel.get(appList.currentIndex)
            launchProcess.command = ["hyprctl", "dispatch", "exec", app.exec]
            if (!launchProcess.running) launchProcess.running = true
            recordProcess.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/app_fetcher.py", "--record", app.name]
            recordProcess.running = true
            
            shellRoot.launcherOpen = false
            searchInput.text = "" 
        }
    }

    Timer {
        id: openDelayTimer
        interval: 30
        onTriggered: openAnim.restart()
    }

    onAllAppsChanged: {
        if (isOpen && searchInput.text === "") {
            filterApps("")
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            if (searchInput.text === "") {
                filterApps("") 
            }
            closeAnim.stop()
            openDelayTimer.restart() 
        } else {
            isFullyOpen = false
            openDelayTimer.stop()
            openAnim.stop()
            closeAnim.restart()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (shellRoot.launcherOpen) shellRoot.launcherOpen = false
    }

    Rectangle {
        id: droplet

        property bool hasHadFocus: false 
        
        Window.onActiveChanged: {
            if (Window.active) {
                hasHadFocus = true 
            } else if (hasHadFocus && launcherRoot.isOpen) {
                launcherRoot.requestClose()
                hasHadFocus = false
            }
        }
        
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
            height: 60 + (appModel.count === 0 ? 0 : Math.min((appModel.count * 56) + 24, 304))
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: 0

            Item {
                id: searchBarContainer
                width: parent.width
                height: 60
                anchors.top: parent.top

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
                        
                        onTextChanged: {
                            launcherRoot.filterApps(text)
                            appList.positionViewAtIndex(0, ListView.Beginning)
                        }
                        
                        Keys.onPressed: event => {
                            let itemsPerPage = 5;
                            let oldPage = Math.floor(appList.currentIndex / itemsPerPage);
                            let handled = false;

                            if (event.key === Qt.Key_Up) {
                                if (appList.currentIndex <= 0) appList.currentIndex = appModel.count - 1;
                                else appList.decrementCurrentIndex();
                                handled = true;
                            } else if (event.key === Qt.Key_Down) {
                                if (appList.currentIndex >= appModel.count - 1) appList.currentIndex = 0;
                                else appList.incrementCurrentIndex();
                                handled = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                launcherRoot.launchSelectedApp();
                                handled = true;
                            } else if (event.key === Qt.Key_Escape) {
                                shellRoot.launcherOpen = false;
                                handled = true;
                            }

                            if (handled) {
                                event.accepted = true;
                                let newPage = Math.floor(appList.currentIndex / itemsPerPage);
                                if (newPage !== oldPage) {
                                    appList.positionViewAtIndex(newPage * itemsPerPage, ListView.Beginning);
                                }
                            }
                        }
                    }
                }
                
                Rectangle { 
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1; 
                    color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.15); 
                    visible: appModel.count > 0 
                }
            }

            ListView {
                id: appList
                anchors.top: searchBarContainer.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                
                model: appModel
                visible: appModel.count > 0 
                clip: true
                interactive: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: appList.contentHeight > appList.height + 2 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    interactive: true
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Theme.accent
                    }
                }

                highlightMoveDuration: 150 

                onVisibleChanged: {
                    if (visible) {
                        currentIndex = 0
                        positionViewAtIndex(0, ListView.Beginning)
                    }
                }
                
                delegate: Rectangle {
                    id: appDelegate 
                    width: appList.width
                    height: 56
                    radius: 8
                    
                    property bool isActive: appList.currentIndex === index || appHover.hovered
                    color: isActive ? Theme.surfaceHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 16
                        
                        Image {
                            source: model.icon.startsWith("/") ? "file://" + model.icon : "image://icon/" + model.icon
                            width: 28; height: 28; sourceSize: Qt.size(28, 28)
                            anchors.verticalCenter: parent.verticalCenter
                            asynchronous: true
                            onStatusChanged: if (status === Image.Error) source = "" 
                        }
                        
                        Text {
                            text: model.name
                            color: Theme.text
                            font.pixelSize: 15
                            font.bold: appDelegate.isActive 
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: appHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            appList.currentIndex = index
                            launcherRoot.launchSelectedApp()
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
            NumberAnimation { target: droplet; property: "height"; to: searchContent.height; duration: 300; easing.type: Easing.OutExpo }
            NumberAnimation { target: droplet; property: "radius"; to: 16; duration: 300; easing.type: Easing.OutExpo }
            NumberAnimation { target: searchContent; property: "opacity"; to: 1; duration: 250 }
        }
        
        ScriptAction { script: searchInput.forceActiveFocus() }
        onFinished: {
            isFullyOpen = true
            if (launcherRoot.isOpen) {
                droplet.height = searchContent.height
            }
        }
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