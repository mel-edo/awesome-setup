import QtQuick
import QtQuick.Layouts

import "../Data/" as Dat
import "../Widgets/" as Wid

RowLayout {
  // Center
  Rectangle {
    Layout.fillHeight: true
    Layout.fillWidth: true
    color: Dat.Colors.surface
    bottomLeftRadius: 20
    bottomRightRadius: 20
  
    Wid.TimePill {
    }
  }
}
