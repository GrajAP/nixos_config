import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs

PanelWindow {
  required property var shell
    id: launcher
    visible: shell.launcherVisible
    focusable: true
    color: "transparent"
    implicitWidth: 520
    implicitHeight: 560
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      onClicked: mouse => {
        const point = mapToItem(launcherPanel, mouse.x, mouse.y);
        if (point.x < 0 || point.y < 0 || point.x > launcherPanel.width || point.y > launcherPanel.height)
          shell.launcherVisible = false;
      }
    }

    Rectangle {
      id: launcherPanel
      width: 500; height: 530; anchors.centerIn: parent
      radius: Theme.radiusLg; color: Theme.panel; border.color: Theme.border; border.width: 1
      ColumnLayout {
        anchors.fill: parent; anchors.margins: 18; spacing: 10
          TextInput {
          id: search
          Layout.fillWidth: true; Layout.preferredHeight: 42
          focus: launcher.visible
          color: Theme.text; font.family: Theme.font; font.pixelSize: 18
          cursorDelegate: shell.themedCursor
          selectionColor: Theme.accent
          selectedTextColor: Theme.background
          selectByMouse: true
          onAccepted: if (appList.count > 0) appList.itemAtIndex(0).launch()
          Keys.onEscapePressed: shell.launcherVisible = false
          Text { anchors.verticalCenter: parent.verticalCenter; visible: !parent.text; text: "Run…"; color: Theme.muted; font: parent.font }
        }
        ListView {
          id: appList
          Layout.fillWidth: true; Layout.fillHeight: true
          clip: true; spacing: 4
          model: ScriptModel {
            values: DesktopEntries.applications.values
              .filter(app => !search.text || (app.name + " " + app.keywords.join(" ")).toLowerCase().includes(search.text.toLowerCase()))
              .sort((a, b) => a.name.localeCompare(b.name))
          }
          delegate: Rectangle {
            id: appRow
            required property var modelData
            width: ListView.view.width; height: 48; radius: 9
            color: "transparent"
            scale: 1
            function launch() { modelData.execute(); shell.launcherVisible = false; search.text = ""; }
            RowLayout {
              anchors.fill: parent; anchors.margins: 7; spacing: 12
              IconImage { implicitSize: 30; source: Quickshell.iconPath(appRow.modelData.icon, "application-x-executable") }
              ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text { text: appRow.modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
                Text { text: appRow.modelData.genericName; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
              }
            }
          }
        }
      }
    }
  }
