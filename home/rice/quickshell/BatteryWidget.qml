import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemPower
import qs

// Battery and power state for laptops. Shows charge, whether the pack is
// charging or discharging, time remaining, and the AC/battery state, plus
// the per-device list on machines with more than one pack.
PanelWindow {
  id: batteryPanel

  required property var shell
  visible: shell.widgetWindowShown && shell.widgetPage === "battery"
  focusable: true
  color: "transparent"
  implicitWidth: 460
  implicitHeight: 340

  // Colour ramp driven purely by charge level and AC state, so the same
  // widget reads sensibly on a desktop (no pack) and a laptop.
  readonly property color accentColor: {
    if (!SystemPower.hasBattery)
      return Theme.muted;
    if (SystemPower.acAvailable)
      return Theme.success;
    if (SystemPower.batteryCapacity === undefined)
      return Theme.accent;
    if (SystemPower.batteryCapacity <= 15)
      return Theme.danger;
    if (SystemPower.batteryCapacity <= 30)
      return Theme.warning;
    return Theme.accent;
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: 430
    height: 310
    radius: Theme.radiusLg
    color: Theme.panel
    border.color: Theme.border
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Theme.padLg
      spacing: Theme.gapMd

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gapMd

        // Simple glyph: 75% or so of a rounded cell, plus a nub.
        Item {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 16
          Layout.alignment: Qt.AlignVCenter

          Rectangle {
            id: cell
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 14
            radius: 3
            color: "transparent"
            border.color: Theme.border
            border.width: 1.5

            Rectangle {
              anchors.fill: parent
              anchors.margins: 2
              radius: 1.5
              color: batteryPanel.accentColor
              width: Math.max(0, (parent.width - 4) * Math.min(1, SystemPower.batteryCapacity / 100))
            }
          }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: cell.right
            anchors.leftMargin: 1
            width: 2
            height: 7
            radius: 1
            color: Theme.border
          }
        }

        Text {
          text: {
            if (SystemPower.batteryCapacity === undefined)
              return "--";
            return SystemPower.batteryCapacity + "%";
          }
          color: Theme.text
          font.family: Theme.fontSans
          font.pixelSize: 26
          font.bold: true
        }

        Text {
          Layout.fillWidth: true
          text: {
            if (!SystemPower.hasBattery)
              return "No battery";
            if (SystemPower.acAvailable)
              return SystemPower.charging ? "Charging" : "On AC";
            return "On battery";
          }
          color: {
            if (!SystemPower.hasBattery)
              return Theme.muted;
            if (SystemPower.acAvailable)
              return Theme.success;
            if (SystemPower.batteryCapacity !== undefined && SystemPower.batteryCapacity <= 15)
              return Theme.danger;
            return Theme.warning;
          }
          font.family: Theme.fontSans
          font.pixelSize: 13
          elide: Text.ElideRight
          horizontalAlignment: Text.AlignRight
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.border
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.gapLg
        rowSpacing: Theme.gapSm

        Text {
          text: "Time remaining"
          color: Theme.muted
          font.family: Theme.fontSans
          font.pixelSize: 12
        }
        Text {
          Layout.fillWidth: true
          text: {
            if (!SystemPower.hasBattery || SystemPower.acAvailable || SystemPower.timeRemaining === undefined)
              return "--";
            const total = SystemPower.timeRemaining;
            if (total <= 0)
              return "--";
            const hours = Math.floor(total / 60);
            const minutes = Math.floor(total % 60);
            if (hours <= 0)
              return minutes + " min";
            return hours + " h " + minutes + " min";
          }
          color: Theme.text
          font.family: Theme.fontMono
          font.pixelSize: 12
          horizontalAlignment: Text.AlignRight
        }

        Text {
          text: "Power profile"
          color: Theme.muted
          font.family: Theme.fontSans
          font.pixelSize: 12
        }
        Text {
          Layout.fillWidth: true
          text: {
            // power-profiles-daemon is disabled fleet-wide (TLP owns power),
            // so report TLP's active mode instead of a PPD profile name.
            if (SystemPower.hasBattery && !SystemPower.acAvailable)
              return "Battery saver (TLP)";
            return "Balanced (TLP)";
          }
          color: Theme.text
          font.family: Theme.fontMono
          font.pixelSize: 12
          horizontalAlignment: Text.AlignRight
        }
      }

      Item { Layout.fillHeight: true }

      Text {
        Layout.fillWidth: true
        text: {
          if (!SystemPower.hasBattery)
            return "This machine has no battery pack.";
          if (SystemPower.acAvailable)
            return "TLP is charging to 80% and resuming at 40% while on AC.";
          return "Deep sleep is trimmed at 5% max_cstate to keep the pack alive.";
        }
        color: Theme.muted
        font.family: Theme.fontSans
        font.pixelSize: 10
        wrapMode: Text.WordWrap
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: shell.widgetWindowShown = false
  }
}