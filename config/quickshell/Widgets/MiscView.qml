import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell
import QtQuick.Layouts

import "../Data/" as Dat

Rectangle {
  color: "transparent"
  property string quote: ""

  ColumnLayout {
    anchors.fill: parent
    spacing: 16

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 100
        color: Dat.Colors.primary_container
        radius: 20

      Text {
        id: quoteText
        anchors.centerIn: parent
        text: quote
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: Dat.Colors.on_surface
        font.pixelSize: 14
        width: parent.width - 25
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 12
      Layout.bottomMargin: 10
      Layout.leftMargin: 60

      Button {
        id: wallpaperSwitcher
        text: "Wallpaper"
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: 25
        Layout.preferredWidth: 70

        background: Rectangle {
            color: {
                if (wallpaperSwitcher.pressed) {
                    return Dat.Colors.surface_container_lowest;
                } else if (wallpaperSwitcher.hovered) {
                    return Dat.Colors.tertiary;
                } else {
                    return Dat.Colors.surface_container_lowest;
                }
            }   
            radius: 20
            border.width: 0
            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
            }
        }

        contentItem: Text {
            text: wallpaperSwitcher.text
            font.pixelSize: 12
            color: {
                if (wallpaperSwitcher.pressed) {
                    return Dat.Colors.on_surface;
                } else if (wallpaperSwitcher.hovered) {
                    return Dat.Colors.primary_container;
                } else {
                    return Dat.Colors.on_surface;
                }
            }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter       
            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
            }
        }
        onClicked: {
            wallpaperShell.running = true;
        }

      }
      Button {
        id: quoteSwitcher
        text: "Quote"
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: 25
        Layout.preferredWidth: 70

        background: Rectangle {
            color: {
                if (quoteSwitcher.pressed) {
                    return Dat.Colors.surface_container_lowest;
                } else if (quoteSwitcher.hovered) {
                    return Dat.Colors.primary;
                } else {
                    return Dat.Colors.surface_container_lowest;
                }
            }   
            radius: 20
            border.width: 0
            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
            }
        }

        contentItem: Text {
            text: quoteSwitcher.text
            font.pixelSize: 12
            color: {
                if (quoteSwitcher.pressed) {
                    return Dat.Colors.on_surface;
                } else if (quoteSwitcher.hovered) {
                    return Dat.Colors.primary_container;
                } else {
                    return Dat.Colors.on_surface;
                }
            }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter       
            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
            }
        }
        onClicked: {
            quoteUpdate.restart();
        }
      }
    }
  }

  Timer {
    id: quoteUpdate
    interval: 600000
    running: true
    repeat: true
    triggeredOnStart: true

    onTriggered: {
        quote = ""
        quoteFetcher.running = false
        quoteFetcher.running = true
    }

  }

  Process {
    id: quoteFetcher
    command: [ "fortune", "-s" ]
    running: false
    stdout: SplitParser {
        onRead: data => {
            if (data.trim().length > 0) {
                quote += (quote.length > 0 ? "\n" : "") + data.trim()
            }
        }
    }
  }

  Process {
    id: wallpaperShell
    command: ["sh", "-c", "~/.config/quickshell/scripts/wallpaper.sh"]
    running: false
  }
}
