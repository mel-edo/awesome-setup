import QtQuick

import "../Data/" as Dat
import "../Generics/" as Gen

Text {
  id: timeText

  anchors.horizontalCenter: parent.horizontalCenter
  anchors.verticalCenter: parent.verticalCenter
  color: Dat.Colors.primary
  font.family: "JetBrains Mono Nerd Font"
  font.pointSize: 12
  font.letterSpacing: 0
  font.hintingPreference: Font.PreferFullHinting
  text: Qt.formatDateTime(Dat.Clock?.date, "ddd MMM d, H:mm:ss")
  bottomPadding: 3

  MouseArea {
    anchors.centerIn: parent
    anchors.fill: null
    height: 20
    width: timeText.contentWidth + 12

    onClicked: {
      if (Dat.Globals.notchState == "FULLY_EXPANDED" && Dat.Globals.swipeIndex == 1) {
        Dat.Globals.notchState = "EXPANDED";
      } else {
        Dat.Globals.notchState = "FULLY_EXPANDED";
        Dat.Globals.swipeIndex = 1;
      }
    }
  }
}
