import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Pam
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs

ShellRoot {
  id: root
  property bool barVisible: true
  property bool launcherVisible: false
  property bool powerVisible: false
  property bool notificationHistoryVisible: false
  property bool notificationPopupVisible: false
  property var latestNotification: null
  property string pendingPassword: ""
  property string authMessage: ""
  property bool osdVisible: false
  property string osdKind: "volume"
  property real osdValue: 0
  readonly property var numerals: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

  GlobalShortcut {
    name: "launcher"
    description: "Toggle application launcher"
    onPressed: { root.powerVisible = false; root.launcherVisible = !root.launcherVisible; }
  }
  GlobalShortcut {
    name: "notifications"
    description: "Toggle notification history"
    onPressed: root.notificationHistoryVisible = !root.notificationHistoryVisible
  }

  IpcHandler {
    target: "notifications"
    function clear(): void {
      const copy = notificationServer.trackedNotifications.values.slice();
      for (const notification of copy) notification.dismiss();
      root.notificationHistoryVisible = false;
    }
  }
  IpcHandler {
    target: "osd"
    function volume(): void {
      root.osdKind = "volume";
      root.osdValue = Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.min(1, Pipewire.defaultAudioSink.audio.volume) : 0;
      root.osdVisible = true; osdTimer.restart();
    }
    function brightness(): void { brightnessQuery.running = true; }
  }
  Timer { id: osdTimer; interval: 1200; onTriggered: root.osdVisible = false }
  Process {
    id: brightnessQuery
    command: ["brightnessctl", "-m"]
    stdout: StdioCollector {
      onStreamFinished: {
        const match = text.match(/,(\d+)%/);
        root.osdKind = "brightness";
        root.osdValue = match ? Number(match[1]) / 100 : 0;
        root.osdVisible = true;
        osdTimer.restart();
      }
    }
  }
  IpcHandler {
    target: "lock"
    function lock(): void { sessionLock.locked = true; }
  }

  NotificationServer {
    id: notificationServer
    actionsSupported: true
    bodyMarkupSupported: true
    imageSupported: true
    persistenceSupported: true
    keepOnReload: true
    onNotification: notification => {
      notification.tracked = true;
      root.latestNotification = notification;
      root.notificationPopupVisible = true;
      popupTimer.restart();
    }
  }
  Timer {
    id: popupTimer
    interval: 5000
    onTriggered: root.notificationPopupVisible = false
  }

  PamContext {
    id: pam
    config: "quickshell"
    onPamMessage: {
      root.authMessage = message;
      if (responseRequired) respond(root.pendingPassword);
    }
    onCompleted: result => {
      if (result === PamResult.Success) {
        root.authMessage = "";
        root.pendingPassword = "";
        sessionLock.locked = false;
      } else {
        root.authMessage = "Authentication failed";
        root.pendingPassword = "";
      }
    }
  }
  WlSessionLock {
    id: sessionLock
    WlSessionLockSurface {
      color: Theme.background
      Rectangle {
        anchors.fill: parent
        color: Theme.background
        ColumnLayout {
          anchors.centerIn: parent
          width: Math.min(420, parent.width - 40)
          spacing: 16
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.text; font.family: Theme.font; font.pixelSize: 68
          }
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: Theme.muted; font.family: Theme.font; font.pixelSize: 16
          }
          Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 52
            radius: 12; color: Theme.surface; border.color: password.activeFocus ? Theme.accent : Theme.muted
            TextInput {
              id: password
              anchors.fill: parent; anchors.margins: 14
              focus: true; echoMode: TextInput.Password
              color: Theme.text; font.family: Theme.font; font.pixelSize: 17
              onAccepted: {
                if (!pam.active && text.length > 0) {
                  root.pendingPassword = text;
                  text = "";
                  pam.start();
                }
              }
            }
          }
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.authMessage || "Enter password to unlock"
            color: root.authMessage ? Theme.danger : Theme.muted
            font.family: Theme.font; font.pixelSize: 12
          }
        }
      }
    }
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

        Repeater {
          model: SystemTray.items
          IconImage {
            required property var modelData
            Layout.alignment: Qt.AlignHCenter
            implicitSize: 20
            source: modelData.icon
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
              onClicked: mouse => {
                if (mouse.button === Qt.RightButton && parent.modelData.hasMenu)
                  parent.modelData.display(bar, 0, mapToItem(bar.contentItem, 0, 0).y);
                else if (mouse.button === Qt.MiddleButton) parent.modelData.secondaryActivate();
                else parent.modelData.activate();
              }
            }
          }
        }

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
    visible: root.notificationPopupVisible && root.latestNotification !== null
    color: "transparent"
    implicitWidth: 390; implicitHeight: 150
    anchors { top: true; right: true }
    margins { top: 18; right: 48 }
    exclusionMode: ExclusionMode.Ignore
    Rectangle {
      anchors.fill: parent; anchors.margins: 4
      radius: 14; color: Theme.background; border.color: Theme.accent; border.width: 2
      RowLayout {
        anchors.fill: parent; anchors.margins: 15; spacing: 12
        IconImage {
          visible: root.latestNotification && root.latestNotification.appIcon
          implicitSize: 42
          source: root.latestNotification ? Quickshell.iconPath(root.latestNotification.appIcon, "dialog-information") : ""
        }
        ColumnLayout {
          Layout.fillWidth: true; Layout.fillHeight: true; spacing: 4
          Text { text: root.latestNotification ? root.latestNotification.appName : ""; color: Theme.accent; font.family: Theme.font; font.pixelSize: 11 }
          Text { Layout.fillWidth: true; text: root.latestNotification ? root.latestNotification.summary : ""; color: Theme.text; font.family: Theme.font; font.bold: true; font.pixelSize: 14; wrapMode: Text.Wrap }
          Text { Layout.fillWidth: true; Layout.fillHeight: true; text: root.latestNotification ? root.latestNotification.body : ""; color: Theme.text; font.family: Theme.font; font.pixelSize: 11; wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 3 }
        }
        Text {
          text: "×"; color: Theme.muted; font.pixelSize: 22
          MouseArea { anchors.fill: parent; onClicked: root.notificationPopupVisible = false }
        }
      }
    }
  }

  PanelWindow {
    visible: root.osdVisible
    color: "transparent"
    implicitWidth: 230; implicitHeight: 64
    anchors { bottom: true }
    margins.bottom: 70
    exclusionMode: ExclusionMode.Ignore
    Rectangle {
      anchors.fill: parent; radius: 14; color: Theme.background; border.color: Theme.accent; border.width: 2
      RowLayout {
        anchors.fill: parent; anchors.margins: 14; spacing: 12
        Text {
          text: root.osdKind === "brightness" ? "󰃠" : (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted ? "󰝟" : "")
          color: Theme.accent; font.family: Theme.font; font.pixelSize: 22
        }
        Rectangle {
          Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: Theme.surface
          Rectangle {
            height: parent.height; radius: parent.radius; color: Theme.accent
            width: parent.width * root.osdValue
          }
        }
      }
    }
  }

  PanelWindow {
    visible: root.notificationHistoryVisible
    focusable: true
    color: "transparent"
    implicitWidth: 420; implicitHeight: 650
    anchors { top: true; right: true; bottom: true }
    margins { top: 18; right: 48; bottom: 18 }
    exclusionMode: ExclusionMode.Ignore
    Rectangle {
      anchors.fill: parent; radius: 16; color: Theme.background; border.color: Theme.accent; border.width: 2
      ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 10
        RowLayout {
          Layout.fillWidth: true
          Text { text: "Notifications"; color: Theme.text; font.family: Theme.font; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true }
          Text {
            text: "Clear"; color: Theme.accent; font.family: Theme.font
            MouseArea { anchors.fill: parent; onClicked: { const copy = notificationServer.trackedNotifications.values.slice(); for (const n of copy) n.dismiss(); } }
          }
        }
        ListView {
          Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8; clip: true
          model: notificationServer.trackedNotifications
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width; height: content.implicitHeight + 24
            radius: 11; color: Theme.surface
            ColumnLayout {
              id: content
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 4
              RowLayout {
                Layout.fillWidth: true
                Text { text: parent.parent.parent.modelData.appName; color: Theme.accent; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                Text { text: "×"; color: Theme.muted; font.pixelSize: 18; MouseArea { anchors.fill: parent; onClicked: parent.parent.parent.parent.modelData.dismiss() } }
              }
              Text { Layout.fillWidth: true; text: parent.parent.modelData.summary; color: Theme.text; font.family: Theme.font; font.bold: true; wrapMode: Text.Wrap }
              Text { Layout.fillWidth: true; text: parent.parent.modelData.body; color: Theme.text; font.family: Theme.font; font.pixelSize: 11; wrapMode: Text.Wrap; textFormat: Text.StyledText }
              RowLayout {
                Layout.fillWidth: true; visible: parent.parent.modelData.actions.length > 0
                Repeater {
                  model: parent.parent.parent.modelData.actions
                  Rectangle {
                    required property var modelData
                    implicitWidth: actionText.implicitWidth + 18; implicitHeight: 28; radius: 7; color: Theme.background
                    Text { id: actionText; anchors.centerIn: parent; text: parent.modelData.text; color: Theme.accent; font.family: Theme.font; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; onClicked: parent.modelData.invoke() }
                  }
                }
              }
            }
          }
        }
      }
      Keys.onEscapePressed: root.notificationHistoryVisible = false
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
            { icon: "󰌾", label: "Lock", command: ["qs", "ipc", "call", "lock", "lock"] },
            { icon: "󰤄", label: "Suspend", command: ["sh", "-c", "qs ipc call lock lock && sleep 0.3 && systemctl suspend"] },
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
