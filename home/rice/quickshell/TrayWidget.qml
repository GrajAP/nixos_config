import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs

ScrollView {
  id: trayScroll
  required property var shell

  Layout.fillWidth: true
  Layout.fillHeight: true
  clip: true
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
  ScrollBar.vertical.policy: contentHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

  ColumnLayout {
    width: trayScroll.availableWidth
    spacing: 10

    Repeater {
      id: trayRepeater
      model: SystemTray.items

      Rectangle {
        id: trayItem
        required property var modelData
        Layout.fillWidth: true
        implicitHeight: 52
        radius: 10
        color: trayItemMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
        border.color: trayItemMouse.containsMouse ? Theme.accent : Theme.border
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 10

          IconImage {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            implicitSize: 24
            source: trayItem.modelData.icon
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
              Layout.fillWidth: true
              text: trayItem.modelData.title || trayItem.modelData.id || "Tray item"
              color: Theme.text
              font.family: Theme.fontSans
              font.pixelSize: 13
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              Layout.fillWidth: true
              text: trayItem.modelData.hasMenu ? "Left click activate, right click menu" : "Left click activate"
              color: Theme.muted
              font.family: Theme.fontSans
              font.pixelSize: 10
              elide: Text.ElideRight
            }
          }
        }

        MouseArea {
          id: trayItemMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onClicked: mouse => {
            if (mouse.button === Qt.RightButton && trayItem.modelData.hasMenu) {
              shell.displayTrayMenu(trayItem.modelData, trayItem, mouse.x, mouse.y);
            } else if (mouse.button === Qt.MiddleButton) {
              trayItem.modelData.secondaryActivate();
              shell.closeWidget();
            } else {
              trayItem.modelData.activate();
              shell.closeWidget();
            }
          }
        }
      }
    }

    Text {
      visible: trayRepeater.count === 0
      Layout.fillWidth: true
      Layout.topMargin: 120
      text: "Tray is empty"
      color: Theme.muted
      font.family: Theme.fontSans
      font.pixelSize: 13
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
