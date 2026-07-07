import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs

ScrollView {
  id: toolsScroll
  required property var shell

  Layout.fillWidth: true
  Layout.fillHeight: true
  clip: true
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
  ScrollBar.vertical.policy: contentHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

  ColumnLayout {
    width: toolsScroll.availableWidth
    spacing: 14

    Text {
      text: "Screenshot"
      color: Theme.muted
      font.family: Theme.fontSans
      font.bold: true
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 44
      radius: Theme.radiusSm
      color: Theme.surface

      Text {
        anchors.centerIn: parent
        text: "󰄀  Select area and edit"
        color: Theme.text
        font.family: Theme.font
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: shell.captureScreenshot("edit", true)
      }
    }
  }
}
