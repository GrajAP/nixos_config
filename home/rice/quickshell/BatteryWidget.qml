import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs

// Battery and power state for laptops, laid out like the audio widget: muted
// labels above 44px rows. Readings come from the shell (sysfs via FileView --
// quickshell 0.3.0 has no SystemPower service) so the panel and the bar glyph
// always agree. The profile row drives TLP, the fleet's only power daemon.
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
    if (shell.batteryPaused)
      return "Charge paused";
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

  Component.onCompleted: shell.refreshBatteryPowerMode()

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
    opacity: shell.batteryTimeRemaining === "--" ? 0.55 : 1

    Text {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      verticalAlignment: Text.AlignVCenter
      text: shell.batteryTimeRemaining
      color: Theme.text
      font.family: Theme.fontMono
      font.pixelSize: 13
      elide: Text.ElideRight
    }
  }

  Text {
    text: shell.batteryCharging ? "Charge speed" : "Power draw"
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
    opacity: shell.batteryWatts < 0 ? 0.55 : 1

    Text {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      verticalAlignment: Text.AlignVCenter
      text: {
        if (shell.batteryWatts < 0)
          return shell.batteryPaused ? "idle" : "--";
        const rate = shell.batteryChargeRate;
        return shell.batteryWatts.toFixed(1) + " W"
          + (rate >= 0 ? "  ·  " + Math.round(rate) + " %/h" : "");
      }
      color: Theme.text
      font.family: Theme.fontMono
      font.pixelSize: 13
      elide: Text.ElideRight
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
    id: profilePicker
    Layout.fillWidth: true
    implicitHeight: 44
    radius: Theme.radiusSm
    color: profileMenu.opened ? Theme.surfaceAlt : Theme.surface
    border.color: profileMenu.opened ? Theme.accent : Theme.border
    border.width: 1
    opacity: shell.batteryHasPack ? 1 : 0.55

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 10
      spacing: 9

      Text {
        text: "󰓢"
        color: profileMenu.opened ? Theme.accent : Theme.muted
        font.family: Theme.fontIcon
        font.pixelSize: 17
        Layout.preferredWidth: 22
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        text: shell.batteryPowerModeText()
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: 13
        Layout.fillWidth: true
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
      }

      Text {
        text: profileMenu.opened ? "⌃" : "⌄"
        color: Theme.muted
        font.family: Theme.fontIcon
        font.pixelSize: 16
        Layout.preferredWidth: 18
        horizontalAlignment: Text.AlignHCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: shell.batteryHasPack
      cursorShape: Qt.PointingHandCursor
      onClicked: profileMenu.opened ? profileMenu.close() : profileMenu.open()
    }

    Menu {
      id: profileMenu
      y: profilePicker.height + 4
      width: profilePicker.width
      onOpened: shell.setHoverWidgetMenuOpen(true)
      onClosed: shell.setHoverWidgetMenuOpen(false)

      background: Rectangle {
        color: Theme.background
        border.color: Theme.border
        border.width: 1
        radius: 8
      }

      Repeater {
        model: [
          {mode: "auto", label: "Auto — follow adapter"},
          {mode: "ac", label: "Performance on AC"},
          {mode: "bat", label: "Battery saver"}
        ]

        MenuItem {
          id: profileItem
          required property var modelData
          text: modelData.label
          checkable: true
          checked: shell.batteryPowerModeSelected(modelData.mode)
          onTriggered: shell.setBatteryPowerMode(modelData.mode)
          implicitHeight: 38
          leftPadding: 24
          rightPadding: 8
          topPadding: 6
          bottomPadding: 6

          indicator: Text {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: profileItem.checked ? "✓" : ""
            color: profileItem.highlighted || profileItem.checked ? Theme.background : Theme.accent
            font.family: Theme.fontIcon
            font.pixelSize: 13
          }

          contentItem: Text {
            leftPadding: profileItem.checkable ? 24 : 0
            rightPadding: 8
            text: profileItem.text
            color: profileItem.highlighted || profileItem.checked ? Theme.background : Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 13
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
          }

          background: Rectangle {
            radius: 7
            color: profileItem.highlighted || profileItem.checked ? Theme.accent : "transparent"
          }
        }
      }
    }
  }

  Item { Layout.fillHeight: true }

  Text {
    Layout.fillWidth: true
    text: {
      if (!shell.batteryHasPack)
        return "This machine has no battery pack, so the bar glyph stays hidden.";
      if (shell.acOnline && !shell.batteryCharging && !shell.batteryPaused)
        return "TLP charges to 80% and resumes at 50% while on AC.";
      return "Deep sleep is trimmed at 5% max_cstate to keep the pack alive.";
    }
    color: Theme.muted
    font.family: Theme.fontSans
    font.pixelSize: 10
    wrapMode: Text.WordWrap
  }
}
