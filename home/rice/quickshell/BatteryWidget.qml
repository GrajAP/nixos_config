import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs

// Battery and power state for laptops, laid out like the audio widget: muted
// labels above 44px rows. Readings come from the shell (sysfs via FileView --
// quickshell 0.3.0 has no SystemPower service) so the panel and the bar glyph
// always agree.
ColumnLayout {
  id: batteryPanel

  required property var shell

  readonly property color accentColor: shell.batteryBarColor
  readonly property int capacity: shell.batteryCapacity
  readonly property string stateText: {
    if (!shell.batteryHasPack)
      return "No battery";
    if (!shell.acOnline)
      return "On battery";
    return shell.batteryCharging ? "Charging" : "On AC";
  }
  readonly property color stateColor: {
    if (!shell.batteryHasPack)
      return Theme.muted;
    if (!shell.acOnline && capacity >= 0 && capacity <= 15)
      return Theme.danger;
    if (!shell.acOnline)
      return Theme.warning;
    return Theme.success;
  }

  Layout.fillWidth: true
  Layout.fillHeight: true
  spacing: 14

  Text {
    text: "Charge"
    color: Theme.muted
    font.family: Theme.fontSans
    font.bold: true
  }

  Rectangle {
    Layout.fillWidth: true
    implicitHeight: 44
    radius: Theme.radiusSm
    color: Theme.surface

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 10

      // Cell outline plus a fill bar whose width tracks the charge.
      Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 16

        Rectangle {
          id: cell
          anchors.verticalCenter: parent.verticalCenter
          width: 24
          height: 13
          radius: 3
          color: "transparent"
          border.color: Theme.border
          border.width: 1.5

          Rectangle {
            x: 2.5
            y: 2.5
            height: cell.height - 5
            width: batteryPanel.capacity < 0
              ? 0
              : Math.max(0, (cell.width - 5) * Math.min(1, batteryPanel.capacity / 100))
            radius: 1
            color: batteryPanel.accentColor
            Behavior on width { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
          }
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: cell.right
          anchors.leftMargin: 1
          width: 2
          height: 6
          radius: 1
          color: Theme.border
        }
      }

      Text {
        text: batteryPanel.capacity < 0 ? "--" : batteryPanel.capacity + "%"
        color: batteryPanel.capacity < 0 ? Theme.muted : Theme.text
        font.family: Theme.fontSans
        font.pixelSize: 13
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        Layout.fillWidth: true
        text: batteryPanel.stateText
        color: batteryPanel.stateColor
        font.family: Theme.fontSans
        font.pixelSize: 13
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }

  Text {
    text: "Power profile"
    color: Theme.muted
    font.family: Theme.fontSans
    font.bold: true
    Layout.topMargin: 4
  }

  Rectangle {
    Layout.fillWidth: true
    implicitHeight: 44
    radius: Theme.radiusSm
    color: Theme.surface

    Text {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      verticalAlignment: Text.AlignVCenter
      // power-profiles-daemon is disabled fleet-wide, so this is TLP's domain
      // rather than a PPD profile name.
      text: shell.acOnline ? "Balanced (TLP)" : "Battery saver (TLP)"
      color: Theme.text
      font.family: Theme.fontMono
      font.pixelSize: 13
      elide: Text.ElideRight
    }
  }

  Text {
    text: "Time remaining"
    color: Theme.muted
    font.family: Theme.fontSans
    font.bold: true
    Layout.topMargin: 4
  }

  Rectangle {
    Layout.fillWidth: true
    implicitHeight: 44
    radius: Theme.radiusSm
    color: Theme.surface
    opacity: 0.55

    Text {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      verticalAlignment: Text.AlignVCenter
      // sysfs exposes no ETA, so this stays honest instead of guessing.
      text: "not reported"
      color: Theme.text
      font.family: Theme.fontMono
      font.pixelSize: 13
      elide: Text.ElideRight
    }
  }

  Item { Layout.fillHeight: true }

  Text {
    Layout.fillWidth: true
    text: {
      if (!shell.batteryHasPack)
        return "This machine has no battery pack, so the bar glyph stays hidden.";
      if (shell.acOnline)
        return "TLP charges to 80% and resumes at 40% while on AC.";
      return "Deep sleep is trimmed at 5% max_cstate to keep the pack alive.";
    }
    color: Theme.muted
    font.family: Theme.fontSans
    font.pixelSize: 10
    wrapMode: Text.WordWrap
  }
}
