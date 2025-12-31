import QtQuick
import QtQuick.Layouts

import "../Data/" as Dat
import "../Widgets/" as Wid
import "../Generics/" as Gen

Rectangle {
  id: root

  color: "transparent"
  required property bool active
  state: (root.active) ? "ACTIVE" : "PASSIVE"
  property alias mArea: mouseArea
  property alias icon: matIcon
  property color activeColor: Dat.Colors.primary
  property color activeIconColor: Dat.Colors.on_primary
  property color passiveColor: Dat.Colors.surface_container
  property color passiveIconColor: Dat.Colors.on_surface

  states: [
    State {
      name: "ACTIVE"

      PropertyChanges {
        bgToggle.color: root.activeColor
        bgToggle.opacity: 1
        bgToggle.visible: true
        bgToggle.width: bgToggle.parent.width
        matIcon.color: root.activeIconColor
        matIcon.fill: 1
      }
    },
    State {
      name: "PASSIVE"

      PropertyChanges {
        bgToggle.color: root.passiveColor
        bgToggle.opacity: 0
        bgToggle.visible: false
        bgToggle.width: 0
        matIcon.color: root.passiveIconColor
        matIcon.fill: 0
      }
    }
  ]
  transitions: [
    Transition {
      from: "PASSIVE"
      to: "ACTIVE"

      SequentialAnimation {
        PropertyAction {
          property: "visible"
          target: bgToggle
        }

        ParallelAnimation {
          NumberAnimation {
            duration: Dat.MaterialEasing.standardTime
            easing.bezierCurve: Dat.MaterialEasing.standard
            properties: "width, opacity"
            target: bgToggle
          }

          ColorAnimation {
            duration: Dat.MaterialEasing.standardTime
            targets: [bgToggle, matIcon]
          }
        }
      }
    },
    Transition {
      from: "ACTIVE"
      to: "PASSIVE"

      SequentialAnimation {
        ParallelAnimation {
          NumberAnimation {
            duration: Dat.MaterialEasing.standardTime
            easing.bezierCurve: Dat.MaterialEasing.standard
            properties: "width, opacity"
            target: bgToggle
          }

          ColorAnimation {
            duration: Dat.MaterialEasing.standardTime
            targets: [bgToggle, matIcon]
          }
        }

        PropertyAction {
          property: "visible"
          target: bgToggle
        }
      }
    }
  ]

  Rectangle {
    id: bgToggle

    anchors.centerIn: parent
    height: this.width
    radius: this.width
  }

  Gen.MatIcon {
    anchors.centerIn: parent
    id: matIcon
    icon: ""
  }

  Gen.MouseArea {
    id: mouseArea
    layerColor: matIcon.color
  }
}
