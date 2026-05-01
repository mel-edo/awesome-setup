//@ pragma UseQApplication
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "."

ShellRoot {
    id: shellRoot
    property bool launcherOpen: false
    property bool overviewOpen: false
    property bool powerMenuOpen: false

    onLauncherOpenChanged: { if (launcherOpen) { overviewOpen = false; powerMenuOpen = false; } }
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
    
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Launcher {
                required property var modelData
                screen: modelData
                isOpen: shellRoot.launcherOpen
                onRequestClose: shellRoot.launcherOpen = false
            }
        }
    }

    LockScreen {}
    
    Overview {
        isOpen: shellRoot.overviewOpen
        onRequestClose: shellRoot.overviewOpen = false
    }

    PowerMenu {
        isOpen: shellRoot.powerMenuOpen
        onRequestClose: shellRoot.powerMenuOpen = false
    }
}