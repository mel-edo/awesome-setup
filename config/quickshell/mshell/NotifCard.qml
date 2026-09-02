import QtQuick
import Quickshell
import "."

Item {
    id: root
    property string nApp: ""
    property string nSum: ""
    property string nBod: ""
    property string nIco: ""
    property string nImg: ""
    property string nTime: ""
    property int index: 0
    property bool isPopup: false

    width: 380
    height: Math.max(iconRect.height + 12, textCol.height + 16)

    opacity: 0
    Component.onCompleted: fadeAnim.start()
    
    NumberAnimation {
        id: fadeAnim
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 300 
        easing.type: Easing.OutCubic
    }

    TapHandler {
        onTapped: {
            notifQueue.remove(root.index) 
            if (root.isPopup) islandWindow.closeToIdle()
        }
    }

    // Application icon
    Rectangle {
        id: iconRect
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 6
        anchors.leftMargin: 12
        width: 40
        height: 40
        radius: 10
        color: Theme.surfaceHover
        clip: true

        Image {
            id: notifImg
            anchors.fill: parent
            anchors.margins: root.nIco.endsWith("symbolic") ? 6 : 0
            source: {
                if (root.nImg !== "") return root.nImg;
                if (root.nIco !== "") return Quickshell.iconPath(root.nIco);
                return "";
            }
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            text: "󰂚"
            color: Theme.subtext
            font.pixelSize: 18
            visible: notifImg.status !== Image.Ready && notifImg.status !== Image.Loading
        }
    }

    // Notification content
    Column {
        id: textCol
        anchors.top: parent.top
        anchors.left: iconRect.right
        anchors.topMargin: 6
        anchors.leftMargin: 12
        spacing: 2
        
        property int textWidth: 300 

        Item {
            width: parent.textWidth
            height: appNameText.implicitHeight

            Text {
                id: appNameText
                anchors.left: parent.left
                anchors.right: timeText.left
                anchors.rightMargin: root.nTime !== "" ? 6 : 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.nApp
                color: Theme.accentAlt
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
            }

            Text {
                id: timeText
                anchors.right: parent.right
                anchors.verticalCenter: appNameText.verticalCenter
                text: root.nTime
                color: Theme.subtext
                font.pixelSize: 10
                visible: root.nTime !== ""
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
            }
        }

        Text {
            text: root.nSum 
            color: Theme.text
            font.pixelSize: 14
            font.bold: true
            width: parent.textWidth
            wrapMode: Text.Wrap 
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
        }

        Item {
            id: bodyClip
            width: parent.textWidth
            height: Math.min(bodyText.implicitHeight, bodyText.font.pixelSize * 1.35 * 4)
            clip: true
            visible: bodyText.text !== ""

            Text {
                id: bodyText
                text: root.nBod
                color: Theme.subtext
                font.pixelSize: 12
                width: parent.width
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                renderType: Text.NativeRendering
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 18
                visible: bodyText.implicitHeight > bodyClip.height
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0) }
                    GradientStop { position: 1.0; color: Theme.surface }
                }
            }
        }
    }
}