// a thin wrapper for placing using Material Symbols
// credit to end for leading me down the making me walk down this route
import QtQuick
import "../Data/" as Dat
Text {
  id: root
  required property string icon
  property real fill: 0
  property int grad: 0
  text: root.icon
  font.family: "Material Symbols Rounded"
  renderType: Text.NativeRendering
  font.hintingPreference: Font.PreferFullHinting
  font.variableAxes: {
    "FILL": root.fill,
    "opsz": root.fontInfo.pixelSize,
    // "GRAD": root.grad,
    "wght": root.fontInfo.weight
  }

  Behavior on fill {
    NumberAnimation {
      duration: Dat.MaterialEasing.standardTime
      easing.bezierCurve: Dat.MaterialEasing.standard
    }
  }
}
