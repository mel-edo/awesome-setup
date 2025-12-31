import QtQuick
import "../Data/" as Dat

MouseArea {
  id: area

  property real clickOpacity: 0.2
  property real hoverOpacity: 0.08
  property color layerColor: "white"
  property NumberAnimation layerOpacityAnimation: NumberAnimation {
    duration: Dat.MaterialEasing.standardTime
    easing.bezierCurve: Dat.MaterialEasing.standard
  }
  property int layerRadius: parent?.radius ?? 0
  property alias layerRect: layer

  anchors.fill: parent
  hoverEnabled: true

  onContainsMouseChanged: layer.opacity = (area.containsMouse) ? area.hoverOpacity : 0
  onContainsPressChanged: layer.opacity = (area.containsPress) ? area.clickOpacity : area.hoverOpacity

  Rectangle {
    id: layer

    anchors.fill: parent
    color: area.layerColor
    opacity: 0
    radius: area.layerRadius

    Behavior on opacity {
      animation: area.layerOpacityAnimation
    }
  }
}
