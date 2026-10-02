import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
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

  // Battery state is read by the shell (sysfs, via FileView -- quickshell 0.3.0
  // has no SystemPower service) and consumed here so both the panel and the bar
  // glyph agree.
  readonly property color accentColor: root.batteryBarColor
  readonly property int capacity: root.batteryCapacity

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
              width: batteryPanel.capacity < 0
                ? 0
                : Math.max(0, (parent.width - 4) * Math.min(1, batteryPanel.capacity / 100))
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
          text: batteryPanel.capacity < 0 ? "--" : batteryPanel.capacity + "%"
          color: Theme.text
          font.family: Theme.fontSans
          font.pixelSize: 26
          font.bold: true
        }

        Text {
          Layout.fillWidth: true
          text: {
            if (!root.batteryHasPack)
              return "No battery";
            if (root.acOnline)
              return root.batteryCharging ? "Charging" : "On AC";
            return "On battery";
          }
          color: {
            if (!root.batteryHasPack)
              return Theme.muted;
            if (root.acOnline)
              return Theme.success;
            if (root.batteryCapacity >= 0 && root.batteryCapacity <= 15)
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
          text: "not reported"
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
          // power-profiles-daemon is disabled fleet-wide, so this is TLP's
          // domain rather than a PPD profile name.
          text: root.acOnline ? "Balanced (TLP)" : "Battery saver (TLP)"
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
          if (!root.batteryHasPack)
            return "This machine has no battery pack.";
          if (root.acOnline)
            return "TLP charges to 80% and resumes at 40% while on AC.";
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