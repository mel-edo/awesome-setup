import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../Data/" as Dat

Scope {
  Variants {
    model: Quickshell.screens

    delegate: WlrLayershell {
      id: notch

      required property ShellScreen modelData

      anchors.left: true
      anchors.right: true
      anchors.top: true
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      focusable: false
      implicitHeight: screen.height * 0.25
      layer: WlrLayer.Top
      namespace: "rexies.notch.quickshell"
      screen: modelData
      surfaceFormat.opaque: false

      mask: Region {
        Region {
          item: notchRect
        }

      }

      Rectangle {
        id: notchRect

        readonly property int baseHeight: 30
        readonly property int baseWidth: 220
        readonly property int expandedHeight: 30
        readonly property int expandedWidth: 650
        readonly property int fullHeight: 190
        readonly property int fullWidth: 650

        anchors.horizontalCenter: parent.horizontalCenter
        bottomLeftRadius: 20
        bottomRightRadius: 20
        clip: true
        color: Dat.Colors.surface
        state: Dat.Globals.notchState

        Behavior on color {
          ColorAnimation {
            duration: Dat.MaterialEasing.standardTime
          }
        }
        states: [
          State {
            name: "COLLAPSED"

            PropertyChanges {
              notchRect.height: notchRect.baseHeight
              notchRect.opacity: 1
              notchRect.width: notchRect.baseWidth
              topBar.visible: true
              expandedPane.visible: false
              topBar.opacity: 1
              expandedPane.opacity: 0
            }
          },
          State {
            name: "EXPANDED"

            PropertyChanges {
              notchRect.height: notchRect.expandedHeight
              notchRect.opacity: 1
              notchRect.width: notchRect.expandedWidth
              topBar.visible: true
              expandedPane.visible: false
              topBar.opacity: 1
              expandedPane.opacity: 0
            }
          },
          State {
            name: "FULLY_EXPANDED"

            PropertyChanges {
              notchRect.height: notchRect.fullHeight
              notchRect.opacity: 1
              notchRect.width: notchRect.fullWidth
              topBar.visible: true
              expandedPane.visible: true
              topBar.opacity: 1
              expandedPane.opacity: 1
            }
          }
        ]
        transitions: [
          Transition {
            from: "COLLAPSED"
            to: "EXPANDED"

            SequentialAnimation {
              PropertyAction {
                target: topBar
                property: "visible"
              }
              PropertyAction {
                property: "opacity"
                target: notchRect
              }
              ParallelAnimation {
                NumberAnimation {
                  duration: Dat.MaterialEasing.standardTime * 2
                  easing.bezierCurve: Dat.MaterialEasing.standard
                  property: "opacity"
                  target: topBar
                }
                NumberAnimation {
                  duration: Dat.MaterialEasing.standardDecelTime
                  easing.bezierCurve: Dat.MaterialEasing.standardDecel
                  properties: "width, opacity, height"
                  target: notchRect
                }
              }
            }
          },
          Transition {
            from: "EXPANDED"
            to: "COLLAPSED"

            SequentialAnimation {
              NumberAnimation {
                duration: (notchRect.height > notchRect.expandedHeight)? (Dat.MaterialEasing.standardAccelTime / 2) : 0
                easing.bezierCurve: Dat.MaterialEasing.standardAccel
                property: "height"
                target: notchRect
                // whenever the workspace changes in quickshell from app1 to app2
                // the global state changes like this: app1 -> desktop -> app2
                // which would cause it to quickly change the stat to EXPANED and then instantly to COLLAPSED
                // and if this condition isn't there, you get a short empty notch
                // since its here you get a 1px tall notch when you you switch between windows workspaces
                // if you manage to spot him, pat yourself in the back, you found the cutie that I hid from caesus
                to: (notchRect.height > notchRect.expandedHeight)? notchRect.expandedHeight : notchRect.height
              }
              ParallelAnimation {
                NumberAnimation {
                  duration: Dat.MaterialEasing.standardAccelTime
                  easing.bezierCurve: Dat.MaterialEasing.standardAccel
                  properties: "width, height"
                  target: notchRect
                }
                NumberAnimation {
                  duration: Dat.MaterialEasing.standardAccelTime
                  easing.bezierCurve: Dat.MaterialEasing.standardAccel
                  property: "opacity"
                  target: topBar
                }
              }
              PropertyAction {
                property: "visible"
                target: topBar
              }
              PropertyAction {
                property: "opacity"
                target: notchRect
              }
            }
          },
          Transition {
            from: "EXPANDED"
            to: "FULLY_EXPANDED"

            SequentialAnimation {
              PropertyAction {
                property: "visible"
                target: expandedPane
              }
              ParallelAnimation {
                NumberAnimation {
                  duration: Dat.MaterialEasing.standardDecelTime
                  easing.bezierCurve: Dat.MaterialEasing.standardDecel
                  property: "height"
                  target: notchRect
                }
                NumberAnimation {
                  duration: Dat.MaterialEasing.standardTime * 3
                  easing.bezierCurve: Dat.MaterialEasing.standard
                  property: "opacity"
                  target: expandedPane
                }
              }
            }
          },
          Transition {
            to: "EXPANDED"
            from: "FULLY_EXPANDED"

            SequentialAnimation {
              ParallelAnimation {
                NumberAnimation {
                  duration: Dat.MaterialEasing.standardAccelTime
                  easing.bezierCurve: Dat.MaterialEasing.standardAccel
                  property: "height"
                  target: notchRect
                }
                NumberAnimation {
                  duration: Dat.MaterialEasing.standardAccelTime
                  easing.bezierCurve: Dat.MaterialEasing.standardAccel
                  property: "opacity"
                  target: expandedPane
                }
              }
              PropertyAction {
                property: "visible"
                target: expandedPane
              }
            }
          },
          // sometimes due to the will of kuru kuru this happens
          // so just make sure it isn't very jagged
          Transition {
            from: "COLLAPSED"
            to: "FULLY_EXPANDED"
            reversible: true

            NumberAnimation {
              duration: Dat.MaterialEasing.emphasizedTime
              easing.bezierCurve: Dat.MaterialEasing.emphasized
              properties: "height, opacity, width"
              target: notchRect
            }
          }
        ]

        // prolly make this a generic later
        MouseArea {
          id: notchArea

          anchors.fill: parent
          hoverEnabled: true

          Timer {
            id: hoverTimer
            interval: 500
            repeat: false
            
            onTriggered: {
              if (Dat.Globals.notchHovered && Dat.Globals.notchState == "EXPANDED") {
                Dat.Globals.notchState = "FULLY_EXPANDED";
              }
            }
          }
          Timer {
            id: collapseTimer
            interval: 500
            repeat: false

            onTriggered: {
              if (!(Dat.Globals.notchHovered)) {
                if (Dat.Globals.notchState == "EXPANDED") {
                  Dat.Globals.notchState = "COLLAPSED";
                }
                if (Dat.Globals.notchState == "FULLY_EXPANDED") {
                  Dat.Globals.notchState = "EXPANDED";
                  collapseTimer.start()
                }
              }
              }
            }

          // IMPORTANT
          onContainsMouseChanged: {
            Dat.Globals.notchHovered = notchArea.containsMouse;

            if (notchArea.containsMouse) {
              collapseTimer.stop();
              Dat.Globals.notchState = "EXPANDED";
              hoverTimer.restart();
            } else {
              collapseTimer.restart();
              hoverTimer.stop();
            }
          }

          ColumnLayout {
            anchors.centerIn: parent
            anchors.fill: parent
            spacing: 0

            TopBar {
              Layout.alignment: Qt.AlignTop
              id: topBar
              Layout.fillWidth: true
              Layout.maximumHeight: notchRect.expandedHeight
              // makes collapse animation look a tiny bit neater
              Layout.minimumHeight: notchRect.expandedHeight - 10
            }

            ExpandedPane {
              id: expandedPane
              Layout.fillHeight: true
              Layout.fillWidth: true
            }
          }
        }
      }
    }
  }
}
