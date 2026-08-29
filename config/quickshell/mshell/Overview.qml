import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "."

Scope {
    id: root

    property bool isOpen: false
    property string pendingFocusAddr: ""
    signal requestClose()
    signal closed()
    signal windowsPopulated()

    IpcHandler {
        target: "overview"
        function toggleOverview(): void {
            shellRoot.overviewOpen = !shellRoot.overviewOpen
        }
    }

    ListModel {
        id: windowModel
    }

    property var allWindows: []
    property var iconMap: ({})
    property var nameMap: ({})

    function normalizeName(str) {
        return str.toLowerCase().replace(/[^a-z0-9]/g, "");
    }
    property var genericClasses: ["steam_proton", "steam_app"]

    function filterWindows(query) {
        windowModel.clear()
        if (allWindows.length === 0) return

        let results = []
        if (query === "") {
            results = allWindows
        } else {
            let fuzzyPattern = query.toLowerCase().split('').join('.*')
            let regex = new RegExp(fuzzyPattern, "i")
            
            results = allWindows.filter(w => regex.test(w.winTitle.toLowerCase()) || regex.test(w.winClass.toLowerCase()))
            
            results.sort((a, b) => {
                let aStarts = (a.winTitle.toLowerCase().startsWith(query.toLowerCase()) || a.winClass.toLowerCase().startsWith(query.toLowerCase())) ? -1 : 1
                let bStarts = (b.winTitle.toLowerCase().startsWith(query.toLowerCase()) || b.winClass.toLowerCase().startsWith(query.toLowerCase())) ? -1 : 1
                return aStarts - bStarts
            })
        }

        for (let i = 0; i < results.length; i++) {
            windowModel.append(results[i])
        }
    }

    Process {
        id: appIconProcess
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/app_fetcher.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") return;
                let apps = JSON.parse(text);
                root.iconMap = {};
                root.nameMap = {};
                for (let i = 0; i < apps.length; i++) {
                    let a = apps[i];
                    if (a.wmClass) root.iconMap[a.wmClass.toLowerCase()] = a.icon;
                    if (a.desktopId) root.iconMap[a.desktopId.toLowerCase()] = a.icon;
                    if (a.name) root.nameMap[normalizeName(a.name)] = a.icon;
                }
            }
        }
    }

    Process {
        id: clientProcess
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") return;
                let windows = JSON.parse(text);
                root.allWindows = [];
                for (let i = 0; i < windows.length; i++) {
                    let w = windows[i];
                    if (w.title !== "") {
                        let wsName = w.workspace ? w.workspace.name : "?";
                        if (wsName.startsWith("special")) wsName = "s";
                        let winClass = w.class || "";

                        let iconName = winClass;
                        let lowerClass = winClass.toLowerCase();

                        if (root.genericClasses.indexOf(lowerClass) !== -1) {
                            let normTitle = normalizeName(w.title);
                            if (root.nameMap[normTitle]) {
                                iconName = root.nameMap[normTitle];
                            } else {
                                // try substring match as a looser fallback
                                let matchKey = Object.keys(root.nameMap).find(k => k.includes(normTitle) || normTitle.includes(k));
                                if (matchKey) iconName = root.nameMap[matchKey];
                            }
                        } else if (root.iconMap[lowerClass]) {
                            iconName = root.iconMap[lowerClass];
                        } else {
                            let entry = DesktopEntries.heuristicLookup(winClass);
                            if (entry && entry.icon) {
                                iconName = entry.icon;
                            } else {
                                if (lowerClass === "codium") iconName = "vscodium";
                                else if (lowerClass === "zen") iconName = "zen-browser";
                                else if (lowerClass === "xreader") iconName = "document-viewer";
                                else if (lowerClass === "com.github.th-ch.youtube-music") iconName = "youtube-music";
                                else if (lowerClass === "steam_proton") iconName = "steam";
                            }
                        }

                        let rawAddress = String(w.address).trim();
                        if (!rawAddress.startsWith("0x")) rawAddress = "0x" + rawAddress;
                        root.allWindows.push({
                            winAddress: rawAddress,
                            winTitle: w.title,
                            winIconName: iconName,
                            winWorkspace: wsName,
                            winClass: winClass
                        });
                    }
                }
                root.filterWindows("");
                root.windowsPopulated();
            }
        }
    }
    Process {
        id: hyprctlFocus
        property string targetAddr: ""
        command: ["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({ window = \"address:" + targetAddr + "\" })'"]
    }

    function selectAndFocus(addr) {
        if (addr && addr !== "") {
            hyprctlFocus.targetAddr = addr
            hyprctlFocus.running = true
        }
        shellRoot.overviewOpen = false
    }

    function populateWindows() {
        if (!appIconProcess.running) appIconProcess.running = true
        if (!clientProcess.running) clientProcess.running = true
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            WlrLayershell {
                id: overviewRoot
                required property var modelData
                screen: modelData

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true
                layer: WlrLayer.Overlay
                
                keyboardFocus: WlrKeyboardFocus.OnDemand 
                color: "transparent"
                
                property bool isActuallyVisible: false
                property bool isExpanded: false
                visible: isActuallyVisible

                function open() {
                    overviewRoot.isExpanded = false
                    closeAnim.stop()
                    overviewRoot.isActuallyVisible = true
                    openAnim.restart()
                    root.populateWindows()
                }

                function close() {
                    openAnim.stop()
                    overviewRoot.isExpanded = false
                    closeAnim.restart()
                }

                // Trigger open animation if already open when the Loader finishes creating this component
                Component.onCompleted: {
                    if (root.isOpen) {
                        overviewRoot.open()
                    }
                }

                Connections {
                    target: root
                    function onIsOpenChanged() {
                        if (root.isOpen) {
                            overviewRoot.open()
                        } else {
                            overviewRoot.close()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: shellRoot.overviewOpen = false
                }

                Rectangle {
                    id: droplet
                    
                    x: (parent.width - width) / 2
                    y: -100
                    width: 40
                    height: overviewRoot.isExpanded ? listContent.height : 40
                    radius: 20

                    Behavior on height {
                        NumberAnimation {
                            duration: root.isOpen ? 300 : 250
                            easing.type: Easing.OutExpo
                        }
                    }
                    
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.2)
                    clip: true

                    Item {
                        id: listContent
                        width: 600
                        height: 60 + (windowModel.count === 0 ? 0 : Math.min((windowModel.count * 56) + 24, 304))
                        
                        anchors.top: parent.top 
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0

                        // Search input
                        Item {
                            id: searchContainer
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
                                    
                                    placeholderText: "Search windows..."
                                    color: Theme.text
                                    placeholderTextColor: Theme.subtext
                                    font.pixelSize: 18
                                    background: Item {} 
                                    
                                    onTextChanged: {
                                        root.filterWindows(text)
                                        windowList.positionViewAtIndex(0, ListView.Beginning)
                                    }
                                    
                                    Keys.onPressed: event => {
                                        let itemsPerPage = 5;
                                        let oldPage = Math.floor(windowList.currentIndex / itemsPerPage);
                                        let handled = false;

                                        if (event.key === Qt.Key_Up) {
                                            if (windowList.currentIndex <= 0) windowList.currentIndex = windowModel.count - 1;
                                            else windowList.decrementCurrentIndex();
                                            handled = true;
                                        } else if (event.key === Qt.Key_Down) {
                                            if (windowList.currentIndex >= windowModel.count - 1) windowList.currentIndex = 0;
                                            else windowList.incrementCurrentIndex();
                                            handled = true;
                                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            if (windowList.currentIndex >= 0 && windowList.currentIndex < windowModel.count) {
                                                let addr = windowModel.get(windowList.currentIndex).winAddress;
                                                root.selectAndFocus(addr);
                                                searchInput.text = ""; 
                                            }
                                            handled = true;
                                        } else if (event.key === Qt.Key_Escape) {
                                            shellRoot.overviewOpen = false;
                                            handled = true;
                                        }

                                        if (handled) {
                                            event.accepted = true;
                                            let newPage = Math.floor(windowList.currentIndex / itemsPerPage);
                                            if (newPage !== oldPage) {
                                                windowList.positionViewAtIndex(newPage * itemsPerPage, ListView.Beginning);
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width; height: 1
                                color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.15)
                                visible: windowModel.count > 0
                            }
                        }

                        ListView {
                            id: windowList
                            anchors.top: searchContainer.bottom
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 12 
                            model: windowModel
                            clip: true
                            interactive: true
                            boundsBehavior: Flickable.StopAtBounds
                            
                            ScrollBar.vertical: ScrollBar {
                                policy: windowList.contentHeight > windowList.height + 2 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
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
                                id: winDelegate 
                                width: windowList.width
                                height: 56
                                radius: 8
                                
                                property bool isActive: windowList.currentIndex === index || hoverArea.hovered
                                color: isActive ? Theme.surfaceHover : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Image {
                                    id: winIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: model.winIconName.startsWith("/") ? "file://" + model.winIconName : "image://icon/" + model.winIconName
                                    width: 28; height: 28
                                    sourceSize: Qt.size(28, 28)
                                    asynchronous: true
                                    onStatusChanged: {
                                        if (status === Image.Error) source = "" 
                                    }
                                }

                                Text {
                                    anchors.left: winIcon.right
                                    anchors.leftMargin: 16
                                    anchors.right: wsBadge.left
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    text: model.winTitle
                                    color: Theme.text
                                    font.pixelSize: 15
                                    font.bold: winDelegate.isActive 
                                    elide: Text.ElideRight 
                                }

                                Rectangle {
                                    id: wsBadge
                                    anchors.right: parent.right
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.05)
                                    border.width: 1
                                    border.color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.15)
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: model.winWorkspace 
                                        color: Theme.subtext
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                HoverHandler { id: hoverArea; cursorShape: Qt.PointingHandCursor }
                                
                                TapHandler {
                                    onTapped: {
                                        windowList.currentIndex = index
                                        let addr = windowModel.get(windowList.currentIndex).winAddress
                                        root.selectAndFocus(addr)
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
                        to: (modelData.height * 0.20) - 30; 
                        duration: 300; 
                        easing.type: Easing.OutExpo 
                    }
                    
                    ScriptAction { script: overviewRoot.isExpanded = true }
                    
                    ParallelAnimation {
                        NumberAnimation { target: droplet; property: "width"; to: 600; duration: 300; easing.type: Easing.OutExpo }
                        NumberAnimation { target: droplet; property: "radius"; to: 16; duration: 300; easing.type: Easing.OutExpo }
                        NumberAnimation { target: listContent; property: "opacity"; to: 1; duration: 250 }
                    }
                    
                    ScriptAction { script: searchInput.forceActiveFocus() }
                }

                SequentialAnimation {
                    id: closeAnim
                    
                    ParallelAnimation {
                        NumberAnimation { target: listContent; property: "opacity"; to: 0; duration: 150 }
                        NumberAnimation { target: droplet; property: "width"; to: 40; duration: 250; easing.type: Easing.OutExpo }
                        NumberAnimation { target: droplet; property: "radius"; to: 20; duration: 250; easing.type: Easing.OutExpo }
                    }
                    
                    NumberAnimation { target: droplet; property: "y"; to: -100; duration: 250; easing.type: Easing.InExpo }
                    
                    ScriptAction { script: searchInput.text = "" }
                    
                    onFinished: {
                        if (!root.isOpen) {
                            overviewRoot.isActuallyVisible = false
                            root.closed()
                        }
                    }
                }
            }
        }
    }
}