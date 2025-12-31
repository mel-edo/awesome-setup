pragma Singleton
import Quickshell
import QtQuick

Singleton {
  readonly property color background: "#181825"
  readonly property color error: "#f38ba8"
  readonly property color on_primary: "#1e1e2e"
  readonly property color on_primary_container: "#b4befe"
  readonly property color on_surface: "#cdd6f4"
  readonly property color on_surface_variant: "#c5c6d0"
  readonly property color primary: "#b4befe"
  readonly property color primary_container: "#1e1e2e"
  readonly property color secondary: "#a6e3a1"
  readonly property color surface: "#181825"
  readonly property color surface_container: "#6c7086"
  readonly property color surface_container_low: "#1e1e2e"
  readonly property color surface_container_lowest: "#313244"
  readonly property color surface_variant: "#45464f"
  readonly property color tertiary: "#cba6f7"
  readonly property color flamingo: "#f2cdcd"

  function withAlpha(color: color, alpha: real): color {
    return Qt.rgba(color.r, color.g, color.b, alpha);
  }
}
