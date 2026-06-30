import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs

ShellRoot {
  id: root
  property bool barVisible: true
  property bool launcherVisible: false
  property bool powerVisible: false
  readonly property var numerals: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

  GlobalShortcut {
    name: "launcher"
    description: "Toggle application launcher"
    onPressed: { root.powerVisible = false; root.launcherVisible = !root.launcherVisible; }
  }
  GlobalShortcut {
    name: "powerMenu"
    description: "Toggle power menu"
    onPressed: { root.launcherVisible = false; root.powerVisible = !root.powerVisible; }
  }
  GlobalShortcut {
    name: "toggleBar"
    description: "Toggle desktop bar"
    onPressed: root.barVisible = !root.barVisible
  }

  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: bar
      required property var modelData
      screen: modelData
      visible: root.barVisible && modelData.name === "DP-1"
      color: Theme.background
      implicitWidth: 34
      anchors { top: true; right: true; bottom: true }
      exclusiveZone: visible ? 34 : 0

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 7

        Repeater {
          model: 10
          Rectangle {
            required property int index
            Layout.fillWidth: true
            implicitHeight: 29
            radius: 7
            color: Hyprland.workspaces.values[index] && Hyprland.workspaces.values[index].active ? Theme.accent : "transparent"
            Text {
              anchors.centerIn: parent
              text: root.numerals[parent.index + 1]
              color: parent.color === Theme.accent ? Theme.background : Theme.text
              font.family: Theme.font
              font.pixelSize: 14
            }
            MouseArea {
              anchors.fill: parent
              onClicked: Hyprland.dispatch("workspace " + (parent.index + 1))
            }
          }
        }

        Item { Layout.fillHeight: true }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
            ? (Pipewire.defaultAudioSink.audio.muted ? "󰝟" : "") : ""
          color: Theme.text
          font.family: Theme.font
          font.pixelSize: 16
          MouseArea {
            anchors.fill: parent
            onClicked: Quickshell.execDetached(["pavucontrol"])
            onWheel: wheel => {
              if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio)
                Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1.5, Pipewire.defaultAudioSink.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
            }
          }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "󰤨"
          color: Theme.text
          font.family: Theme.font
          font.pixelSize: 15
          MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
        }

        SystemClock { id: clock; precision: SystemClock.Seconds }
        Text {
          Layout.alignment: Qt.AlignHCenter
          text: Qt.formatDateTime(clock.date, "HH\nmm\ndd\nMM")
          horizontalAlignment: Text.AlignHCenter
          color: Theme.text
          font.family: Theme.font
          font.pixelSize: 11
          lineHeight: 0.9
          MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["obsidian"]) }
        }
      }
    }
  }

  PanelWindow {
    id: launcher
    visible: root.launcherVisible
    focusable: true
    color: "transparent"
    implicitWidth: 520
    implicitHeight: 560
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      width: 500; height: 530; anchors.centerIn: parent
      radius: 16; color: Theme.background; border.color: Theme.accent; border.width: 2
      ColumnLayout {
        anchors.fill: parent; anchors.margins: 18; spacing: 10
        TextInput {
          id: search
          Layout.fillWidth: true; Layout.preferredHeight: 42
          focus: launcher.visible
          color: Theme.text; font.family: Theme.font; font.pixelSize: 18
          selectByMouse: true
          onAccepted: if (appList.count > 0) appList.itemAtIndex(0).launch()
          Keys.onEscapePressed: root.launcherVisible = false
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
            color: rowMouse.containsMouse ? Theme.surface : "transparent"
            function launch() { modelData.execute(); root.launcherVisible = false; search.text = ""; }
            RowLayout {
              anchors.fill: parent; anchors.margins: 7; spacing: 12
              IconImage { implicitSize: 30; source: Quickshell.iconPath(appRow.modelData.icon, "application-x-executable") }
              ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text { text: appRow.modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
                Text { text: appRow.modelData.genericName; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
              }
            }
            MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; onClicked: appRow.launch() }
          }
        }
      }
    }
  }

  PanelWindow {
    visible: root.powerVisible
    focusable: true
    color: "transparent"
    implicitWidth: 480; implicitHeight: 170
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    Rectangle {
      width: 450; height: 140; anchors.centerIn: parent
      radius: 16; color: Theme.background; border.color: Theme.accent; border.width: 2
      RowLayout {
        anchors.fill: parent; anchors.margins: 18; spacing: 12
        Repeater {
          model: [
            { icon: "󰌾", label: "Lock", command: ["hyprlock"] },
            { icon: "󰤄", label: "Suspend", command: ["systemctl", "suspend"] },
            { icon: "󰜉", label: "Reboot", command: ["systemctl", "reboot"] },
            { icon: "󰐥", label: "Power", command: ["systemctl", "poweroff"] }
          ]
          Rectangle {
            required property var modelData
            Layout.fillWidth: true; Layout.fillHeight: true; radius: 12
            color: powerMouse.containsMouse ? (modelData.label === "Power" ? Theme.danger : Theme.surface) : Theme.surface
            ColumnLayout {
              anchors.centerIn: parent
              Text { text: parent.parent.modelData.icon; color: Theme.text; font.family: Theme.font; font.pixelSize: 28; Layout.alignment: Qt.AlignHCenter }
              Text { text: parent.parent.modelData.label; color: Theme.text; font.family: Theme.font; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
            }
            MouseArea { id: powerMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.powerVisible = false; Quickshell.execDetached(parent.modelData.command); } }
          }
        }
      }
    }
  }
}
