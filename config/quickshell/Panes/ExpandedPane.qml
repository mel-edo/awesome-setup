import QtQuick
import QtQuick.Layouts

import "../Data/" as Dat

Rectangle {
  id: root

  clip: true
  color: Dat.Colors.surface
  radius: 20

  RowLayout {
    anchors.fill: parent
    spacing: 0

    CentralPane {
      Layout.minimumHeight: 145
      Layout.fillWidth: true
      radius: root.radius
    }

    KuruKuru {
      Layout.fillHeight: true
      Layout.fillWidth: true
      radius: root.radius
    }
  }
}
