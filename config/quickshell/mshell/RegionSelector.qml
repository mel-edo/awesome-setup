import QtQuick
import Quickshell
import "."

Scope {
    id: root

    Variants {
        model: Quickshell.screens

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
