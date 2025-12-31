pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
  id: root

  property string actWinName: activeWindow?.activated ? activeWindow?.appId : "~/"
  readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
  property string hostName: "ganymede"
  property bool notchHovered: false

  // one of "COLLAPSED", "EXPANDED", "FULLY_EXPANDED"
  property string notchState: (reservedShell) ? "EXPANDED" : "COLLAPSED"
  // one of "HIDDEN", "POPUP", "INBOX"
  property string notifState: "HIDDEN"
  property bool reservedShell: false

  // SettingsView State
  // 0 => Power
  // 1 => Audio
  // 2 => Network
  property int settingsTabIndex: 0

  // Central Panel SwipeView stuff
  // 0 => Home
  // 1 => Calendar
  // 2 => System
  // 3 => Mpris
  // 4 => SettingsView
  property int swipeIndex: 0

  onActWinNameChanged: {
    if (reservedShell) {
      return;
    }
  }
}
