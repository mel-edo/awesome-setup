import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "."

ShellRoot {
    id: shellRoot
    property bool launcherOpen: false
    property bool overviewOpen: false
    property bool powerMenuOpen: false
    property var globalAllApps: []
    property bool controlCenterOpen: false
    
    Process {
        id: globalAppFetchProcess
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/mshell/scripts/app_fetcher.py"]
        Component.onCompleted: running = true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    shellRoot.globalAllApps = JSON.parse(text.trim())
                } catch(e) {}
            }
        }
    }

    onLauncherOpenChanged: { 
        if (launcherOpen) { 
            overviewOpen = false; powerMenuOpen = false; controlCenterOpen = false; 
            if (!globalAppFetchProcess.running) globalAppFetchProcess.running = true;
        } 
    }
    onOverviewOpenChanged: { if (overviewOpen) { launcherOpen = false; powerMenuOpen = false; controlCenterOpen = false; } }
    onPowerMenuOpenChanged: { if (powerMenuOpen) { launcherOpen = false; overviewOpen = false; controlCenterOpen = false; } }
    onControlCenterOpenChanged: { if (controlCenterOpen) { launcherOpen = false; overviewOpen = false; powerMenuOpen = false; } }

    GlobalShortcut {
        name: "toggleLauncher"
        onPressed: shellRoot.launcherOpen = !shellRoot.launcherOpen
    }

    GlobalShortcut {
        name: "toggleOverview"
        onPressed: shellRoot.overviewOpen = !shellRoot.overviewOpen
    }

    GlobalShortcut {
        name: "togglePowerMenu"
        onPressed: shellRoot.powerMenuOpen = !shellRoot.powerMenuOpen
    }

    Bar {}
    Island {}
    LockScreen {}
    
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Loader {
                id: launcherLoader
                required property var modelData
                Connections {
                    target: shellRoot
                    function onLauncherOpenChanged() {
                        if (shellRoot.launcherOpen) launcherLoader.active = true;
                    }
                }
                Connections {
                    target: launcherLoader.item
                    function onVisibleChanged() {
                        if (launcherLoader.item && !launcherLoader.item.visible && !shellRoot.launcherOpen) {
                            Qt.callLater(function() {
                                launcherLoader.active = false;
                            });
                        }
                    }
                }

                sourceComponent: Component {
                    Launcher {
                        screen: modelData
                        isOpen: shellRoot.launcherOpen
                        allApps: shellRoot.globalAllApps
                        onRequestClose: shellRoot.launcherOpen = false
                    }
                }
            }
        }
    }
    
    Loader {
        id: overviewLoader
        
        Connections {
            target: shellRoot
            function onOverviewOpenChanged() {
                if (shellRoot.overviewOpen) overviewLoader.active = true;
            }
        }
        Connections {
            target: overviewLoader.item
            function onVisibleChanged() {
                if (overviewLoader.item && !overviewLoader.item.visible && !shellRoot.overviewOpen) {
                    Qt.callLater(function() {
                        overviewLoader.active = false;
                    });
                }
            }
        }

        sourceComponent: Component {
            Overview {
                isOpen: shellRoot.overviewOpen
                onRequestClose: shellRoot.overviewOpen = false
            }
        }
    }

    Loader {
        id: powerMenuLoader
        
        Connections {
            target: shellRoot
            function onPowerMenuOpenChanged() {
                if (shellRoot.powerMenuOpen) powerMenuLoader.active = true;
            }
        }
        Connections {
            target: powerMenuLoader.item
            function onVisibleChanged() {
                if (powerMenuLoader.item && !powerMenuLoader.item.visible && !shellRoot.powerMenuOpen) {
                    Qt.callLater(function() {
                        powerMenuLoader.active = false;
                    });
                }
            }
        }

        sourceComponent: Component {
            PowerMenu {
                isOpen: shellRoot.powerMenuOpen
                onRequestClose: shellRoot.powerMenuOpen = false
            }
        }
    }
}