import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs

PanelWindow {
  required property var shell
    visible: shell.codexUsageVisible
    focusable: true
    color: "transparent"
    implicitWidth: 270
    implicitHeight: 170
    anchors { bottom: true; right: true }
    margins { bottom: 72; right: 54 }
    exclusionMode: ExclusionMode.Ignore
    MouseArea {
      anchors.fill: parent
      onClicked: shell.codexUsageVisible = false
    }
    Rectangle {
      width: parent.width
      height: parent.height
      focus: shell.codexUsageVisible
      radius: Theme.radiusLg
      color: Theme.panel
      border.color: Theme.border
      border.width: 1
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.padMd
        spacing: 8
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "◉  Codex usage"
            color: Theme.text
            font.family: Theme.fontSans
            font.bold: true
            font.pixelSize: 16
            Layout.fillWidth: true
          }
          Text { text: "×"; color: Theme.muted; font.pixelSize: 20; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.codexUsageVisible = false } }
        }
        Text {
          Layout.fillWidth: true
          text: shell.codexUsageError.length > 0 ? ("Error: " + shell.codexUsageError) : (shell.codexUsage ? shell.codexUsageSummaryText() : "No data yet")
          color: shell.codexUsageError.length > 0 ? Theme.danger : Theme.text
          font.family: Theme.fontSans
          font.pixelSize: 13
          wrapMode: Text.Wrap
        }
        Text {
          Layout.fillWidth: true
          visible: !!shell.codexUsage
          text: shell.codexUsageTooltipText()
          color: Theme.muted
          font.family: Theme.font
          font.pixelSize: 11
          wrapMode: Text.Wrap
          elide: Text.ElideRight
        }
      }
      Keys.onEscapePressed: shell.codexUsageVisible = false
    }
  }
