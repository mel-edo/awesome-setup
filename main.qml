//@ pragma UseQApplication
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "."

ShellRoot {
    id: shellRoot
    property bool launcherOpen: false
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
}