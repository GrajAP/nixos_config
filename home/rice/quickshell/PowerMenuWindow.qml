import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs

PanelWindow {
  required property var shell
    visible: shell.powerVisible
    focusable: true
    color: "transparent"
    implicitWidth: 480; implicitHeight: 170
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    MouseArea {
      anchors.fill: parent
      enabled: shell.powerVisible
      onClicked: mouse => {
        const point = mapToItem(powerPanel, mouse.x, mouse.y);
        if (point.x < 0 || point.y < 0 || point.x > powerPanel.width || point.y > powerPanel.height)
          shell.powerVisible = false;
      }
    }
    Rectangle {
      id: powerPanel
      width: 450; height: 140; anchors.centerIn: parent
      focus: shell.powerVisible
      radius: Theme.radiusLg; color: Theme.panel; border.color: Theme.border; border.width: 1
      RowLayout {
        anchors.fill: parent; anchors.margins: Theme.padLg; spacing: Theme.gapMd
        Repeater {
          model: [
            { icon: "󰌾", label: "Lock", command: ["secure-session-lock"] },
            { icon: "󰤄", label: "Suspend", command: ["sh", "-c", "secure-session-lock & sleep 0.5 && systemctl suspend"] },
            { icon: "󰜉", label: "Reboot", command: ["systemctl", "reboot"] },
            { icon: "󰐥", label: "Power", command: ["systemctl", "poweroff"] }
          ]
          Rectangle {
            required property var modelData
            Layout.fillWidth: true; Layout.fillHeight: true; radius: 12
            color: Theme.surface
            ColumnLayout {
              anchors.centerIn: parent
              Text { text: parent.parent.modelData.icon; color: Theme.text; font.family: Theme.font; font.pixelSize: 28; Layout.alignment: Qt.AlignHCenter }
              Text { text: parent.parent.modelData.label; color: Theme.text; font.family: Theme.font; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
            }
            MouseArea {
              id: powerMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                shell.powerVisible = false;
                if (parent.modelData.command.length > 0) Quickshell.execDetached(parent.modelData.command);
              }
            }
          }
        }
      }
      Keys.onEscapePressed: shell.powerVisible = false
    }
  }
