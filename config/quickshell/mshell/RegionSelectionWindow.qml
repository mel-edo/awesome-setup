import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: root

    required property var targetScreen
    screen: targetScreen
    visible: RegionSelectionService.active
    color: "transparent"

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "mshell-region-selector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real pointerX: width / 2
    property real pointerY: height / 2
    property real dragStartX: 0
    property real dragStartY: 0
    property real dragCurrentX: 0
    property real dragCurrentY: 0
    property bool dragging: false

    readonly property real selectionX: Math.min(dragStartX, dragCurrentX)
    readonly property real selectionY: Math.min(dragStartY, dragCurrentY)
    readonly property real selectionWidth: Math.abs(dragCurrentX - dragStartX)
    readonly property real selectionHeight: Math.abs(dragCurrentY - dragStartY)
    readonly property bool hasSelection: selectionWidth > 0 && selectionHeight > 0

    readonly property color scrimColor: Qt.rgba(0, 0, 0, 0.52)
    readonly property color guideColor: Theme.accent
    readonly property color guideMuted: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
    readonly property color selectionFill: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)

    function resetSelection() {
        root.dragging = false;
        root.dragStartX = 0;
        root.dragStartY = 0;
        root.dragCurrentX = 0;
        root.dragCurrentY = 0;
    }

    function finishSelection() {
        if (!RegionSelectionService.accept(
            root.targetScreen,
            root.selectionX,
            root.selectionY,
            root.selectionWidth,
            root.selectionHeight
        )) {
            root.resetSelection();
        }
    }

    onVisibleChanged: {
        if (visible) {
            resetSelection();
            keyboardGateway.forceActiveFocus();
        }
    }

    mask: Region {
        item: interactionArea
    }

    Item {
        id: keyboardGateway
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                RegionSelectionService.cancel();
            }
        }
    }

    Image {
        id: frozenBackground
        anchors.fill: parent
        source: root.visible ? ("file:///dev/shm/mshell_freeze_" + root.targetScreen.name + ".png?" + RegionSelectionService.freezeTimestamp) : ""
        cache: false
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: root.scrimColor
        visible: !root.hasSelection
    }

    Item {
        anchors.fill: parent
        visible: root.hasSelection

        // Top region
        Rectangle {
            x: 0; y: 0
            width: parent.width
            height: root.selectionY
            color: root.scrimColor
        }

        // Bottom region
        Rectangle {
            x: 0
            y: root.selectionY + root.selectionHeight
            width: parent.width
            height: Math.max(0, parent.height - y)
            color: root.scrimColor
        }

        // Left region
        Rectangle {
            x: 0
            y: root.selectionY
            width: root.selectionX
            height: root.selectionHeight
            color: root.scrimColor
        }

        // Right region
        Rectangle {
            x: root.selectionX + root.selectionWidth
            y: root.selectionY
            width: Math.max(0, parent.width - x)
            height: root.selectionHeight
            color: root.scrimColor
        }
    }

    // Horizontal crosshair line
    Rectangle {
        x: 0
        y: Math.round(root.pointerY)
        width: parent.width
        height: 1
        color: root.guideMuted
    }

    // Vertical crosshair line
    Rectangle {
        x: Math.round(root.pointerX)
        y: 0
        width: 1
        height: parent.height
        color: root.guideMuted
    }

    // Selection frame
    Rectangle {
        id: selectionFrame
        x: Math.round(root.selectionX)
        y: Math.round(root.selectionY)
        width: Math.round(root.selectionWidth)
        height: Math.round(root.selectionHeight)
        radius: 4
        visible: root.hasSelection
        color: root.selectionFill
        border.width: 2
        border.color: root.guideColor
    }

    // Dimension readout badge
    Rectangle {
        id: dimensionLabel
        readonly property real preferredX: root.selectionX + root.selectionWidth - width
        readonly property real preferredY: root.selectionY > height + 20
            ? root.selectionY - height - 8
            : root.selectionY + root.selectionHeight + 8

        x: Math.max(12, Math.min(preferredX, root.width - width - 12))
        y: Math.max(12, Math.min(preferredY, root.height - height - 12))
        width: dimensionRow.implicitWidth + 24
        height: 32
        radius: 16
        visible: root.hasSelection
        color: Theme.surface
        border.width: 1
        border.color: Theme.highlight

        RowLayout {
            id: dimensionRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "󰄀"
                color: Theme.accent
                font.pixelSize: 14
            }

            Text {
                text: Math.round(root.selectionWidth) + " × " + Math.round(root.selectionHeight)
                font.pixelSize: 12
                font.bold: true
                color: Theme.text
            }
        }
    }

    // Instruction banner
    Rectangle {
        id: instructionLabel
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 24
        }
        width: instructionRow.implicitWidth + 28
        height: 36
        radius: 18
        color: Theme.surface
        border.width: 1
        border.color: Theme.highlight

        RowLayout {
            id: instructionRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: RegionSelectionService.currentAction === "ocr" ? "󰈙" : "󰹑"
                font.pixelSize: 15
                color: Theme.accent
            }

            Text {
                text: RegionSelectionService.currentAction === "ocr"
                    ? "Drag to extract text (OCR)  ·  Esc or Right-click to cancel"
                    : "Drag to select screenshot region  ·  Esc or Right-click to cancel"
                font.pixelSize: 13
                font.bold: true
                color: Theme.text
            }
        }
    }

    MouseArea {
        id: interactionArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor

        onPositionChanged: mouse => {
            root.pointerX = mouse.x;
            root.pointerY = mouse.y;
            if (root.dragging) {
                root.dragCurrentX = Math.max(0, Math.min(mouse.x, root.width));
                root.dragCurrentY = Math.max(0, Math.min(mouse.y, root.height));
            }
        }

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                RegionSelectionService.cancel();
                return;
            }
            keyboardGateway.forceActiveFocus();
            root.pointerX = mouse.x;
            root.pointerY = mouse.y;
            root.dragStartX = Math.max(0, Math.min(mouse.x, root.width));
            root.dragStartY = Math.max(0, Math.min(mouse.y, root.height));
            root.dragCurrentX = root.dragStartX;
            root.dragCurrentY = root.dragStartY;
            root.dragging = true;
        }

        onReleased: mouse => {
            if (mouse.button === Qt.RightButton)
                return;

            if (!root.dragging)
                return;

            root.dragCurrentX = Math.max(0, Math.min(mouse.x, root.width));
            root.dragCurrentY = Math.max(0, Math.min(mouse.y, root.height));
            root.dragging = false;
            root.finishSelection();
        }
    }
}
