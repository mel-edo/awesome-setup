import Quickshell
import QtQuick
import "."

ShellRoot {
    Component.onCompleted: {
        console.log("[mshell] loaded ok")
    }
    Bar {}
}