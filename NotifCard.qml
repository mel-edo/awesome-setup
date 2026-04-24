import QtQuick
import Quickshell
import "."

Item {
    id: root
    
    // 1. THE SCOPE FIX: Explicitly require the variables from the ListModel!
    required property string nApp
    required property string nSum
    required property string nBod
    required property string nIco
    required property string nImg

    width: 380
    height: Math.max(68, textCol.height + 24)

    // 2. THE LAG FIX: Start completely invisible and let the GPU fade it in smoothly
    opacity: 0
    
    Component.onCompleted: fadeAnim.start()
    
    NumberAnimation {
        id: fadeAnim
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 300 // Fades in smoothly right as the pill finishes expanding
        easing.type: Easing.OutCubic
    }

    // --- ICON ---
    Rectangle {
        id: iconRect
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 12
        anchors.leftMargin: 12
        width: 44
        height: 44
        radius: 12
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
            font.pixelSize: 20
            visible: notifImg.status !== Image.Ready && notifImg.status !== Image.Loading
        }
    }

    // --- TEXT BLOCK (Native Column, No Heavy Formatting) ---
    Column {
        id: textCol
        anchors.top: parent.top
        anchors.left: iconRect.right
        anchors.topMargin: 12
        anchors.leftMargin: 12
        spacing: 2
        
        property int textWidth: 300 

        Text {
            text: root.nApp 
            color: Theme.accentAlt
            font.pixelSize: 11
            font.bold: true
            width: parent.textWidth
            elide: Text.ElideRight
            textFormat: Text.PlainText
            renderType: Text.NativeRendering // Uses OS font renderer (Fast!)
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
            renderType: Text.NativeRendering // Uses OS font renderer (Fast!)
        }

        Text {
            text: root.nBod 
            color: Theme.subtext
            font.pixelSize: 12
            width: parent.textWidth
            wrapMode: Text.Wrap 
            maximumLineCount: 4 
            elide: Text.ElideRight
            visible: text !== ""
            textFormat: Text.PlainText
            renderType: Text.NativeRendering // Uses OS font renderer (Fast!)
        }
    }
}