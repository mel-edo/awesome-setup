//@ pragma UseQApplication
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
            overviewOpen = false; powerMenuOpen = false; 
            if (!globalAppFetchProcess.running) globalAppFetchProcess.running = true;
        } 
    }
    onOverviewOpenChanged: { if (overviewOpen) { launcherOpen = false; powerMenuOpen = false; } }
    onPowerMenuOpenChanged: { if (powerMenuOpen) { launcherOpen = false; overviewOpen = false; } }

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
                required property var modelData
                active: shellRoot.launcherOpen || (item && item.visible)
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
        active: shellRoot.overviewOpen || (item && item.visible)
        sourceComponent: Component {
            Overview {
                isOpen: shellRoot.overviewOpen
                onRequestClose: shellRoot.overviewOpen = false
            }
        }
    }

    Loader {
        active: shellRoot.powerMenuOpen || (item && item.visible)
        sourceComponent: Component {
            PowerMenu {
                isOpen: shellRoot.powerMenuOpen
                onRequestClose: shellRoot.powerMenuOpen = false
            }
        }
    }
}