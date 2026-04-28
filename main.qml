//@ pragma UseQApplication
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "."

ShellRoot {
    id: shellRoot
    property bool launcherOpen: false
    property bool overviewOpen: false
    onLauncherOpenChanged: { if (launcherOpen) overviewOpen = false }
    onOverviewOpenChanged: { if (overviewOpen) launcherOpen = false }

    GlobalShortcut {
        name: "toggleLauncher"
        onPressed: shellRoot.launcherOpen = !shellRoot.launcherOpen
    }

    Bar {}
    Island {}
    
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Launcher {
                required property var modelData
                screen: modelData
                isOpen: shellRoot.launcherOpen
            }
        }
    }

    // LockScreen {}
    Overview {
        isOpen: shellRoot.overviewOpen
    }
}