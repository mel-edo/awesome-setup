import QtQuick
import Quickshell
import "."

Scope {
    id: root

    Variants {
        model: Quickshell.screens.filter(s => s && s.name && !s.name.startsWith("EXT") && !s.name.startsWith("HEADLESS") && !s.name.startsWith("NOOP"))

        delegate: Loader {
            id: selectorLoader
            required property var modelData

            active: true
            sourceComponent: RegionSelectionWindow {
                targetScreen: selectorLoader.modelData
            }
        }
    }
}
