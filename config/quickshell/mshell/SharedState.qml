pragma Singleton
import QtQuick

Item {
    id: root
    property bool isSuppressingOsd: false
    property bool isOsdActive: false
    property int currentOsdValue: 50
    property string currentOsdType: "volume"
    property bool isScreenSharing: false

    signal osdRequested(int value, string type)

    Timer {
        id: osdActiveTimer
        interval: 2500
        onTriggered: root.isOsdActive = false
    }

    function triggerOsd(value, type) {
        if (!isSuppressingOsd) {
            currentOsdValue = value
            currentOsdType = type
            isOsdActive = true
            osdActiveTimer.restart()
            root.osdRequested(value, type)
        }
    }
}
