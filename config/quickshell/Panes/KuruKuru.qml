import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

import "../Data/" as Dat
import "../Widgets/" as Wid

Rectangle {
  color: "transparent"

  RowLayout {
    anchors.fill: parent

    Rectangle {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.preferredWidth: 1.45
        color: "transparent"

        Text {
          id: greeting
          Layout.fillHeight: true
          Layout.fillWidth: true
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.leftMargin: 15
          anchors.topMargin: 25
          font.bold: true
          font.pixelSize: 18
          color: Dat.Colors.primary
          
          text: ""

          Timer {
            interval: 1800000
            triggeredOnStart: true
            repeat: true
            running: true

            onTriggered: {
              const now = new Date();
              const hour = now.getHours();

              if (5 <= hour && hour < 12) {
                greeting.text = "Good Morning,";
              } else if (12 <= hour && hour < 16) {
                greeting.text = "Good Afternoon,";
              } else if (16 <= hour && hour < 21) {
                greeting.text = "Good Evening,";
              } else if (21 <= hour || hour < 1) {
                greeting.text = "Good Night,";
              } else {
                greeting.text = "Rest Well,";
                console.log(hour);
              }
            }
          }
        }
        
        // why is the shell script just running the python file, I could probably fix it using subprocess in python
        // i'm not fixing it


        Text {
            id: sampleText

            property string weather: "Fetching.."

            Layout.fillHeight: true
            Layout.fillWidth: true
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 20
            anchors.topMargin: 65
            font.pixelSize: 15
            color: Dat.Colors.on_surface
            text: weather
        }

        Timer {
          id: weatherFetch
          interval: 1800000
          triggeredOnStart: true
          running: true
          repeat: true

          onTriggered: {
            weatherShell.running = true;
          }
        }

        Process {
          id: weatherShell
          running: false
          command: ["sh", "-c", "~/.config/quickshell/scripts/weather.sh"]
          stdout: SplitParser {
            onRead: data => {
              if (data.trim().length > 0) {
                sampleText.weather = data;
              }
            }
          }
        }

      RowLayout {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: 65
        anchors.bottom: parent.bottom
        anchors.leftMargin: 25
        spacing: 10


        Button {
            id: toggleDND
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            checkable: true
            checked: false

            background: Rectangle {
                anchors.fill: parent
                radius: 14
                color: {
                    if (toggleDND.hovered || toggleDND.checked) {
                        return Dat.Colors.error;
                    } else {
                        return Dat.Colors.surface_container_lowest;
                    }
                }
                border.color: Dat.Colors.surface_container_low
                border.width: 1
                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            contentItem: IconImage {
                anchors.centerIn: parent
                source: {
                    if (toggleDND.checked || toggleDND.hovered) {
                        return Qt.resolvedUrl("../svg/dino-status-dnd-active");
                    } else {
                        return Qt.resolvedUrl("../svg/dino-status-dnd");
                    }
                }
                width: 24
                height: parent.height
            }

            onClicked: {
                swayncclientDND.running = true;
            }

            Process {
                id: swayncclientDND
                running: false
                command: ["swaync-client", "-d"]
            }
        }

        Button {
            id: idleInhibit
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            checkable: true
            checked: false

            background: Rectangle {
                anchors.fill: parent
                radius: 14
                color: {
                    if (idleInhibit.hovered || idleInhibit.checked) {
                        return Dat.Colors.flamingo;
                    } else {
                        return Dat.Colors.surface_container_lowest;
                    }
                }
                border.color: Dat.Colors.surface_container_low
                border.width: 1
                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            contentItem: IconImage {
                anchors.centerIn: parent
                source: {
                    if (idleInhibit.checked || idleInhibit.hovered) {
                        return Qt.resolvedUrl("../svg/caffeine-cup-full");
                    } else {
                        return Qt.resolvedUrl("../svg/caffeine-cup-empty");
                    }
                }
                width: 24
                height: parent.height
            }

            onClicked: {
                lockInhibitSh.running = true;
            }

            Process {
                id: lockInhibitSh
                command: ["sh", "-c", "~/.config/quickshell/scripts/matcha/bin/matcha -t"]
                running: false
            }
        }

        Button {
            id: toggleNoti
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            checkable: true
            checked: false

            background: Rectangle {
                anchors.fill: parent
                radius: 14
                color: {
                    if (toggleNoti.hovered || toggleNoti.checked) {
                        return Dat.Colors.secondary;
                    } else {
                        return Dat.Colors.surface_container_lowest;
                    }
                }
                border.color: Dat.Colors.surface_container_low
                border.width: 1
                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            contentItem: IconImage {
                anchors.centerIn: parent
                source: {
                    if (toggleNoti.checked || toggleNoti.hovered) {
                        return Qt.resolvedUrl("../svg/notification-symbolic-active");
                    } else {
                        return Qt.resolvedUrl("../svg/notification-symbolic");
                    }
                }
                width: 22
                height: parent.height
            }

            onClicked: {
                swayncclientNoti.running = true;
            }

            Connections {
                target: Dat.Globals
                function onNotchStateChanged() {
                    if (Dat.Globals.notchState != "FULLY_EXPANDED") {
                        toggleNoti.checked = false;
                    }
                }
            }

            Process {
                id: swayncclientNoti
                running: false
                command: ["swaync-client", "-t"]
            }
        }
      }
    }

    ColumnLayout {
      Layout.fillHeight: true
      Layout.fillWidth: true
      Layout.preferredWidth: 1

      // Rectangle { // the hando that squishes the kuru kuru
      //   id: squishRect

      //   Layout.fillWidth: true
      //   color: "transparent"
      //   implicitHeight: 0
      //   state: "NOSQUISH"

      //   states: [
      //     State {
      //       name: "NOSQUISH"

      //       PropertyChanges {
      //         squishRect.implicitHeight: 0
      //       }
      //     },
      //     State {
      //       name: "SQUISH"

      //       PropertyChanges {
      //         squishRect.implicitHeight: 40
      //       }
      //     }
      //   ]
      //   transitions: [
      //     Transition {
      //       from: "NOSQUISH"
      //       to: "SQUISH"

      //       NumberAnimation {
      //         duration: 100
      //         easing.bezierCurve: Dat.MaterialEasing.standardAccel
      //         property: "implicitHeight"
      //       }
      //     },
      //     Transition {
      //       from: "SQUISH"
      //       to: "NOSQUISH"

      //       NumberAnimation {
      //         duration: Dat.MaterialEasing.standardDecelTime
      //         easing.bezierCurve: Dat.MaterialEasing.standardDecel
      //         property: "implicitHeight"
      //       }
      //     }
      //   ]
      // }

      // Rectangle {
      //   id: gifRect

      //   property bool playing: false
      //   property real speed: 0.8
      //   property bool switchable: true

      //   Layout.fillHeight: true
      //   Layout.fillWidth: true
      //   color: "transparent"
      //   state: "HERTA"

      //   states: [
      //     State {
      //       name: "HERTA"

      //       PropertyChanges {
      //         big.opacity: 0
      //         big.visible: false
      //         smoll.opacity: 1
      //         smoll.visible: true
      //       }
      //     },
      //     State {
      //       name: "THE_HERTA"

      //       PropertyChanges {
      //         big.opacity: 1
      //         big.visible: true
      //         smoll.opacity: 0
      //         smoll.visible: false
      //       }
      //     }
      //   ]
      //   transitions: [
      //     Transition {
      //       from: "HERTA"
      //       to: "THE_HERTA"

      //       SequentialAnimation {
      //         PropertyAction {
      //           property: "visible"
      //           target: big
      //         }

      //         NumberAnimation {
      //           duration: 500
      //           easing.type: Easing.Linear
      //           property: "opacity"
      //           targets: [big, smoll]
      //         }

      //         PropertyAction {
      //           property: "visible"
      //           target: smoll
      //         }
      //       }
      //     },
      //     Transition {
      //       from: "THE_HERTA"
      //       to: "HERTA"

      //       SequentialAnimation {
      //         PropertyAction {
      //           property: "visible"
      //           target: smoll
      //         }

      //         NumberAnimation {
      //           duration: 500
      //           easing.type: Easing.Linear
      //           property: "opacity"
      //           targets: [big, smoll]
      //         }

      //         PropertyAction {
      //           property: "visible"
      //           target: big
      //         }
      //       }
      //     }
      //   ]

      //   Component.onCompleted: {
      //     Dat.Globals.notchStateChanged.connect(() => {
      //       if (Dat.Globals.notchState == "FULLY_EXPANDED") {
      //         gifRect.playing = true;
      //       }
      //     });
      //   }
      //   onSpeedChanged: {
      //     if (gifRect.speed > 8) {
      //       if (gifRect.switchable) {
      //         gifRect.state = (gifRect.state == "HERTA") ? "THE_HERTA" : "HERTA";
      //       }
      //       gifRect.switchable = false;
      //     }
      //     if (gifRect.speed < 7) {
      //       gifRect.switchable = true;
      //     }

      //     if (gifRect.speed > 5) {
      //       pSystem.running = true;
      //     }

      //     if (gifRect.speed < 1) {
      //       pSystem.running = false;
      //     }
      //   }

      //   Timer {
      //     interval: 500
      //     running: Dat.Globals.notchState != "FULLY_EXPANDED" && parent.playing == true

      //     onTriggered: {
      //       parent.playing = false;
      //     }
      //   }

      //   Timer {
      //     id: squisher

      //     interval: 50
      //     repeat: true
      //     running: squishRect.state == "SQUISH"

      //     onTriggered: parent.speed += 0.1
      //   }

      //   Timer {
      //     id: stoptheKuruKuru

      //     interval: 50
      //     repeat: true
      //     running: squishRect.state != "SQUISH" && parent.speed > 0.8

      //     onTriggered: parent.speed -= 0.05
      //   }

      //   AnimatedImage {
      //     id: smoll

      //     anchors.fill: parent
      //     anchors.rightMargin: 8
      //     fillMode: Image.PreserveAspectCrop
      //     horizontalAlignment: Image.AlignRight
      //     playing: parent.playing && smoll.visible
      //     // source: "https://duiqt.github.io/herta_kuru/static/img/hertaa1.gif"
      //     source: "https://media1.tenor.com/m/k9HSD_gGtyoAAAAd/seseren.gif"
      //     speed: parent.speed
      //   }

      //   AnimatedImage {
      //     id: big

      //     anchors.bottomMargin: -13
      //     anchors.fill: parent
      //     fillMode: Image.PreserveAspectFit
      //     horizontalAlignment: Image.AlignRight
      //     playing: parent.playing && big.visible
      //     source: "https://media.tenor.com/taxnt3zsc_4AAAAj/seseren-the-herta.gif"
      //     speed: parent.speed
      //   }


      //   MouseArea {
      //     acceptedButtons: Qt.LeftButton
      //     anchors.fill: parent

      //     onPressedChanged: {
      //       squishRect.state = (squishRect.state == "SQUISH") ? "NOSQUISH" : "SQUISH";

      //     }
      //   }
      // }
        Rectangle {
            id: gifRect
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            // — Properties —
            property bool playing: true
            property real speed: 0.8
            property int currentGif: 0

            // List of GIFs
            property var gifList: [
                "../Tenor-unscreen.gif", // Kirara
                "https://media.tenor.com/vJb0PaoKkcUAAAAj/genshin-yoimiya.gif", // Yoimiya
                "https://media1.tenor.com/m/9fCMVU-f3kYAAAAC/keqing-genshin-impact.gif", // Keqing
                "https://media1.tenor.com/m/DlPk4su1mJoAAAAd/layla.gif" // Layla
            ]

            // Per-GIF offset configuration
            // Use x/y scale or margin adjustments depending on your preference
            property var gifOffsets: [
                { x: -500, y: 0, scale: 0.4 },         // Kirara
                { x: 10, y: -500, scale: 0.6 },      // Yoimiya
                { x: -15, y: 0, scale: 0.25 },      // Keqing
                { x: 0, y: 10, scale: 0.2 }         // Layla
            ]

            // — Active/Next layers for fade —
            AnimatedImage {
                id: activeGif
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                opacity: 1.0
                playing: gifRect.playing
                speed: gifRect.speed
                transform: Scale { id: activeScale; origin.x: activeGif.width/2; origin.y: activeGif.height/2; xScale: 1; yScale: 1 }
            }

            // Make the next Animated image lazy load when the current one is on display
            // for smooth fade to next

            AnimatedImage {
                id: nextGif
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                opacity: 0.0
                visible: false
                playing: false
                transform: Scale { id: nextScale; origin.x: nextGif.width/2; origin.y: nextGif.height/2; xScale: 1; yScale: 1 }
            }

            // — Fade Animation —
            SequentialAnimation {
                id: fadeAnim
                PropertyAnimation { target: activeGif; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InOutQuad }
                ScriptAction { script: {
                    // Apply nextGif to active
                    activeGif.source = nextGif.source
                    activeGif.opacity = 1
                    activeGif.playing = true
                    activeGif.x = nextGif.x
                    activeGif.y = nextGif.y
                    activeScale.xScale = nextScale.xScale
                    activeScale.yScale = nextScale.yScale
                    nextGif.visible = false
                }}
            }

            // — Cycle on click —
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    const nextIndex = (gifRect.currentGif + 1) % gifRect.gifList.length
                    const newSrc = gifRect.gifList[nextIndex]
                    const offs = gifRect.gifOffsets[nextIndex]

                    nextGif.source = newSrc
                    nextGif.visible = true
                    nextGif.opacity = 0
                    nextGif.playing = gifRect.playing

                    // Apply offsets
                    nextGif.x = offs.x
                    nextGif.y = offs.y
                    nextScale.xScale = offs.scale
                    nextScale.yScale = offs.scale

                    fadeAnim.restart()
                    gifRect.currentGif = nextIndex
                }
            }

            // — Load initial GIF lazily —
            Component.onCompleted: {
                activeGif.source = gifList[0]
                const offs = gifOffsets[0]
                activeGif.x = offs.x
                activeGif.y = offs.y
                activeScale.xScale = offs.scale
                activeScale.yScale = offs.scale
        }
      
      }
    }
  }

  MultiEffect {
    anchors.fill: pSystem
    maskEnabled: true
    maskSource: mask
    maskSpreadAtMin: 1.0
    maskThresholdMax: 1.0
    maskThresholdMin: 0.5
    source: pSystem
  }

  Item {
    id: mask

    visible: false
    width: pSystem.width
    height: pSystem.height
    layer.enabled: true
    Rectangle {
      anchors.fill: parent
      bottomLeftRadius: 20
      bottomRightRadius: 20
    }
  }
}
