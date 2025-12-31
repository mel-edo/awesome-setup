pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

import "../Generics/" as Gen
import "../Data/" as Dat
import "../Widgets/" as Wid

Rectangle {
  color: "transparent"

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 5

    Rectangle {
      Layout.fillHeight: true
      Layout.fillWidth: true
      color: Dat.Colors.surface_container_low
      radius: 20

      StackView {
        // visible: false
        id: stack

        anchors.fill: parent

        initialItem: Wid.GreeterWidget {
          height: stack.height
          width: stack.width
        }
        popEnter: Transition {
          PropertyAnimation {
            duration: Dat.MaterialEasing.emphasizedTime
            from: 0
            property: "opacity"
            to: 1
          }
        }
        popExit: Transition {
          PropertyAnimation {
            duration: Dat.MaterialEasing.emphasizedTime
            from: 1
            property: "opacity"
            to: 0
          }
        }
        pushEnter: Transition {
          PropertyAnimation {
            duration: Dat.MaterialEasing.emphasizedTime
            from: 0
            property: "opacity"
            to: 1
          }
        }
        pushExit: Transition {
          PropertyAnimation {
            duration: Dat.MaterialEasing.emphasizedTime
            from: 1
            property: "opacity"
            to: 0
          }
        }
      }
    }
  }
}
