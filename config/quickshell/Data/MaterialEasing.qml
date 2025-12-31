pragma Singleton
import Quickshell

Singleton {
  id: root

  // thanks to Soramane :>
  readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
  readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
  readonly property int emphasizedAccelTime: 200
  readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
  readonly property int emphasizedDecelTime: 400
  readonly property int emphasizedTime: 500
  readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
  readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
  readonly property int standardAccelTime: 200
  readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
  readonly property int standardDecelTime: 250
  readonly property int standardTime: 300
}
