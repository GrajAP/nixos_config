import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
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
  property bool widgetVisible: false
  property string widgetPage: "audio"
  property string networkStatus: "Loading…"
  property bool wifiEnabled: true
  property var wifiNetworks: []
  property var weatherData: null
  property var calendarEvents: []
  readonly property var mediaPlayer: Mpris.players.values.find(player => player.identity.toLowerCase().includes("spotify")) || Mpris.players.values[0] || null
  readonly property var numerals: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
  SystemClock { id: clock; precision: SystemClock.Seconds }

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
  Process {
    id: networkQuery
    command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
    stdout: StdioCollector {
      onStreamFinished: {
        const connected = text.split("\n").find(line => line.includes(":connected:"));
        root.networkStatus = connected ? connected.split(":").slice(2).join(":") : "Disconnected";
      }
    }
  }
  Process {
    id: wifiQuery
    command: ["nmcli", "radio", "wifi"]
    stdout: StdioCollector { onStreamFinished: root.wifiEnabled = text.trim() === "enabled" }
  }
  Process {
    id: weatherQuery
    command: ["@weatherQuery@"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.weatherData = JSON.parse(text);
        } catch (error) {
          root.weatherData = null;
        }
      }
    }
  }
  Process {
    id: calendarQuery
    command: ["@calendarQuery@"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const payload = JSON.parse(text);
          root.calendarEvents = payload.events || [];
        } catch (error) {
          root.calendarEvents = [];
        }
      }
    }
  }
  Process {
    id: wifiScan
    command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SSID", "device", "wifi", "list", "--rescan", "no"]
    stdout: StdioCollector {
      onStreamFinished: root.wifiNetworks = text.trim().split("\n").filter(line => line.length > 0).map(line => {
        const fields = line.split(":");
        return { active: fields[0] === "*", signal: Number(fields[1]), ssid: fields.slice(2).join(":") };
      }).filter((network, index, all) => network.ssid && all.findIndex(item => item.ssid === network.ssid) === index).slice(0, 12)
    }
  }
  Process { id: networkAction; onExited: { networkQuery.running = true; wifiQuery.running = true; } }
  Component.onCompleted: {
    networkQuery.running = true;
    wifiQuery.running = true;
    wifiScan.running = true;
    weatherQuery.running = true;
    calendarQuery.running = true;
  }
  Timer {
    interval: 15 * 60 * 1000
    running: true
    repeat: true
    onTriggered: weatherQuery.running = true
  }

  function openWidget(page) {
    widgetPage = page;
    widgetVisible = true;
    if (page === "network") { networkQuery.running = true; wifiQuery.running = true; wifiScan.running = true; }
    if (page === "weather") weatherQuery.running = true;
    if (page === "calendar") calendarQuery.running = true;
  }
  function dateKey(date) {
    return Qt.formatDateTime(date, "yyyy-MM-dd");
  }
  function weatherGlyph() {
    const code = root.weatherData ? Number(root.weatherData.weatherCode) : NaN;
    if (code === 0) return "󰖙";
    if ([1, 2, 3].includes(code)) return "󰖐";
    if ([45, 48].includes(code)) return "󰖑";
    if ([51, 53, 55, 56, 57].includes(code)) return "󰖗";
    if ([61, 63, 65, 66, 67, 80, 81, 82].includes(code)) return "󰖖";
    if ([71, 73, 75, 77].includes(code)) return "󰼶";
    if ([95, 96, 99].includes(code)) return "󰖓";
    return "󰖙";
  }
  function monthCells() {
    const year = clock.date.getFullYear();
    const month = clock.date.getMonth();
    const firstDay = (new Date(year, month, 1).getDay() + 6) % 7;
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const today = dateKey(clock.date);
    const counts = {};
    for (const event of root.calendarEvents) {
      counts[event.date] = (counts[event.date] || 0) + 1;
    }
    const cells = [];
    for (let index = 0; index < 42; index++) {
      const day = index - firstDay + 1;
      if (day < 1 || day > daysInMonth) {
        cells.push({ inMonth: false, day: 0, date: "", isToday: false, eventCount: 0 });
        continue;
      }
      const cellDate = new Date(year, month, day);
      const key = dateKey(cellDate);
      cells.push({
        inMonth: true,
        day,
        date: key,
        isToday: key === today,
        eventCount: counts[key] || 0
      });
    }
    return cells;
  }
  function upcomingEvents(limit) {
    const today = dateKey(clock.date);
    return root.calendarEvents
      .filter(event => event.date >= today)
      .slice()
      .sort((a, b) => a.date.localeCompare(b.date) || a.title.localeCompare(b.title))
      .slice(0, limit || 6);
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

  PwObjectTracker { objects: Pipewire.nodes.values.filter(node => node.audio !== null) }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: bar
      required property var modelData
      screen: modelData
      visible: root.barVisible && modelData.name === "DP-1"
      color: Theme.background
      implicitWidth: 44
      anchors { top: true; right: true; bottom: true }
      exclusiveZone: visible ? 44 : 0

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 7

        Repeater {
          model: 10
          Rectangle {
            required property int index
            readonly property int workspaceId: index + 1
            readonly property var workspace: Hyprland.workspaces.values.find(candidate => candidate.id === workspaceId)
            Layout.fillWidth: true
            implicitHeight: 34
            radius: 7
            color: workspace && workspace.active ? Theme.accent : "transparent"
            Text {
              anchors.centerIn: parent
              text: root.numerals[parent.workspaceId]
              color: parent.color === Theme.accent ? Theme.background : Theme.text
              font.family: Theme.font
              font.pixelSize: 14
            }
            MouseArea {
              anchors.fill: parent
              onClicked: Hyprland.dispatch("workspace " + parent.workspaceId)
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
            onClicked: root.openWidget("audio")
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
          MouseArea { anchors.fill: parent; onClicked: root.openWidget("network") }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: root.mediaPlayer && root.mediaPlayer.isPlaying ? "󰏤" : "󰐊"
          color: root.mediaPlayer ? Theme.text : Theme.muted
          font.family: Theme.font; font.pixelSize: 16
          MouseArea { anchors.fill: parent; onClicked: root.openWidget("media") }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: root.weatherData ? Math.round(root.weatherData.temperature) + "°" : root.weatherGlyph()
          color: Theme.text; font.family: Theme.font; font.pixelSize: 14
          MouseArea { anchors.fill: parent; onClicked: root.openWidget("weather") }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: Qt.formatDateTime(clock.date, "dd")
          color: Theme.text
          font.family: Theme.font
          font.pixelSize: 16
          MouseArea { anchors.fill: parent; onClicked: root.openWidget("calendar") }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: notificationServer.trackedNotifications.values.length > 0 ? "󰂚" : "󰂜"
          color: Theme.text; font.family: Theme.font; font.pixelSize: 16
          MouseArea { anchors.fill: parent; onClicked: root.notificationHistoryVisible = !root.notificationHistoryVisible }
        }
      }
    }
  }

  PanelWindow {
    id: widgetWindow
    visible: root.widgetVisible
    focusable: true
    color: "transparent"
    implicitWidth: 410; implicitHeight: 560
    anchors { right: true; bottom: true }
    margins { right: 54; bottom: 18 }
    exclusionMode: ExclusionMode.Ignore
    Rectangle {
      anchors.fill: parent; radius: 16; color: Theme.background; border.color: Theme.accent; border.width: 2
      ColumnLayout {
        anchors.fill: parent; anchors.margins: 18; spacing: 12
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: ({audio: "Audio", network: "Network", media: "Now playing", weather: "Weather", calendar: "Calendar"})[root.widgetPage]
            color: Theme.text; font.family: Theme.font; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true
          }
          Text { text: "×"; color: Theme.muted; font.pixelSize: 22; MouseArea { anchors.fill: parent; onClicked: root.widgetVisible = false } }
        }

        ColumnLayout {
          visible: root.widgetPage === "audio"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
          Text {
            text: Pipewire.defaultAudioSink ? (Pipewire.defaultAudioSink.description || Pipewire.defaultAudioSink.name) : "No output"
            color: Theme.text; font.family: Theme.font; wrapMode: Text.Wrap; Layout.fillWidth: true
          }
          RowLayout {
            Layout.fillWidth: true
            Text {
              text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted ? "󰝟" : ""
              color: Theme.accent; font.family: Theme.font; font.pixelSize: 22
              MouseArea { anchors.fill: parent; onClicked: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted }
            }
            Slider {
              Layout.fillWidth: true; from: 0; to: 1.5
              value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
              onMoved: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.volume = value
            }
            Text { text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "0%"; color: Theme.text; font.family: Theme.font }
          }
          Text { text: "Outputs"; color: Theme.muted; font.family: Theme.font; font.bold: true }
          ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6; clip: true
            model: ScriptModel { values: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream) }
            delegate: Rectangle {
              required property var modelData
              width: ListView.view.width; height: 42; radius: 9
              color: modelData === Pipewire.defaultAudioSink ? Theme.accent : Theme.surface
              Text { anchors.fill: parent; anchors.margins: 10; verticalAlignment: Text.AlignVCenter; text: parent.modelData.description || parent.modelData.nickname || parent.modelData.name; color: parent.modelData === Pipewire.defaultAudioSink ? Theme.background : Theme.text; font.family: Theme.font; elide: Text.ElideRight }
              MouseArea { anchors.fill: parent; onClicked: Pipewire.preferredDefaultAudioSink = parent.modelData }
            }
          }
        }

        ColumnLayout {
          visible: root.widgetPage === "network"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
          Text { text: "󰤨  " + root.networkStatus; color: Theme.text; font.family: Theme.font; font.pixelSize: 16 }
          RowLayout {
            Layout.fillWidth: true
            Text { text: "Wi-Fi"; color: Theme.text; font.family: Theme.font; Layout.fillWidth: true }
            Switch { checked: root.wifiEnabled; onToggled: networkAction.exec(["nmcli", "radio", "wifi", checked ? "on" : "off"]) }
          }
          Rectangle {
            Layout.fillWidth: true; implicitHeight: 42; radius: 9; color: Theme.surface
            Text { anchors.centerIn: parent; text: "Rescan and refresh"; color: Theme.accent; font.family: Theme.font }
            MouseArea { anchors.fill: parent; onClicked: { networkAction.exec(["nmcli", "device", "wifi", "rescan"]); wifiScan.running = true; } }
          }
          ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6; clip: true
            model: root.wifiNetworks
            delegate: Rectangle {
              required property var modelData
              width: ListView.view.width; height: 42; radius: 9
              color: modelData.active ? Theme.accent : Theme.surface
              RowLayout {
                anchors.fill: parent; anchors.margins: 10
                Text { text: parent.parent.modelData.signal > 70 ? "󰤨" : parent.parent.modelData.signal > 40 ? "󰤥" : "󰤟"; color: parent.parent.modelData.active ? Theme.background : Theme.text; font.family: Theme.font }
                Text { text: parent.parent.modelData.ssid; color: parent.parent.modelData.active ? Theme.background : Theme.text; font.family: Theme.font; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { text: parent.parent.modelData.signal + "%"; color: parent.parent.modelData.active ? Theme.background : Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
              }
              MouseArea { anchors.fill: parent; onClicked: if (!parent.modelData.active) networkAction.exec(["nmcli", "connection", "up", "id", parent.modelData.ssid]) }
            }
          }
        }

        ColumnLayout {
          visible: root.widgetPage === "media"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
          Image { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 220; Layout.preferredHeight: 220; fillMode: Image.PreserveAspectCrop; source: root.mediaPlayer ? root.mediaPlayer.trackArtUrl : "" }
          Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.mediaPlayer ? (root.mediaPlayer.trackTitle || "Unknown title") : "No media player"; color: Theme.text; font.family: Theme.font; font.bold: true; font.pixelSize: 17; wrapMode: Text.Wrap }
          Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.mediaPlayer ? root.mediaPlayer.trackArtist : ""; color: Theme.muted; font.family: Theme.font }
          RowLayout {
            Layout.alignment: Qt.AlignHCenter; spacing: 28
            Text { text: "󰒮"; color: Theme.text; font.family: Theme.font; font.pixelSize: 25; MouseArea { anchors.fill: parent; onClicked: if (root.mediaPlayer && root.mediaPlayer.canGoPrevious) root.mediaPlayer.previous() } }
            Text { text: root.mediaPlayer && root.mediaPlayer.isPlaying ? "󰏤" : "󰐊"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 30; MouseArea { anchors.fill: parent; onClicked: if (root.mediaPlayer && root.mediaPlayer.canTogglePlaying) root.mediaPlayer.togglePlaying() } }
            Text { text: "󰒭"; color: Theme.text; font.family: Theme.font; font.pixelSize: 25; MouseArea { anchors.fill: parent; onClicked: if (root.mediaPlayer && root.mediaPlayer.canGoNext) root.mediaPlayer.next() } }
          }
        }

        ColumnLayout {
          visible: root.widgetPage === "weather"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
          Text { Layout.alignment: Qt.AlignHCenter; text: root.weatherData ? root.weatherGlyph() : "󰖙"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 62 }
          Text { Layout.alignment: Qt.AlignHCenter; text: root.weatherData ? Math.round(root.weatherData.temperature) + "°C" : "Loading weather…"; color: Theme.text; font.family: Theme.font; font.pixelSize: 30; font.bold: true }
          Text { Layout.alignment: Qt.AlignHCenter; text: root.weatherData ? root.weatherData.description : ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: 14 }
          RowLayout {
            Layout.fillWidth: true
            Text { text: "Feels like"; color: Theme.muted; font.family: Theme.font; Layout.fillWidth: true }
            Text { text: root.weatherData && root.weatherData.apparentTemperature !== null && root.weatherData.apparentTemperature !== undefined ? Math.round(root.weatherData.apparentTemperature) + "°C" : "—"; color: Theme.text; font.family: Theme.font }
          }
          RowLayout {
            Layout.fillWidth: true
            Text { text: "Wind"; color: Theme.muted; font.family: Theme.font; Layout.fillWidth: true }
            Text { text: root.weatherData && root.weatherData.windSpeed !== null && root.weatherData.windSpeed !== undefined ? Math.round(root.weatherData.windSpeed) + " km/h" : "—"; color: Theme.text; font.family: Theme.font }
          }
          RowLayout {
            Layout.fillWidth: true
            Text { text: "Today"; color: Theme.muted; font.family: Theme.font; Layout.fillWidth: true }
            Text { text: root.weatherData && root.weatherData.todayMin !== null && root.weatherData.todayMax !== null ? Math.round(root.weatherData.todayMin) + "° / " + Math.round(root.weatherData.todayMax) + "°" : "—"; color: Theme.text; font.family: Theme.font }
          }
        }

        ColumnLayout {
          visible: root.widgetPage === "calendar"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
          Text { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy"); color: Theme.text; font.family: Theme.font; font.pixelSize: 18; font.bold: true }
          Text { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDateTime(clock.date, "HH:mm:ss"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 13 }
          GridLayout {
            Layout.fillWidth: true; columns: 7; rowSpacing: 8; columnSpacing: 8
            Repeater {
              model: ["M", "T", "W", "T", "F", "S", "S"]
              Text {
                required property string modelData
                text: modelData
                color: Theme.accent
                font.family: Theme.font
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
              }
            }
            Repeater {
              model: root.monthCells()
              Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 8
                color: !modelData.inMonth ? "transparent" : modelData.isToday ? Theme.accent : Theme.surface
                border.color: modelData.eventCount > 0 && modelData.inMonth && !modelData.isToday ? Theme.accent : "transparent"
                border.width: modelData.eventCount > 0 && modelData.inMonth && !modelData.isToday ? 1 : 0
                Text {
                  anchors.centerIn: parent
                  text: modelData.inMonth ? modelData.day : ""
                  color: modelData.isToday ? Theme.background : Theme.text
                  font.family: Theme.font
                }
                Rectangle {
                  visible: modelData.inMonth && modelData.eventCount > 0
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: 4
                  implicitWidth: Math.min(18, 5 + modelData.eventCount * 4)
                  implicitHeight: 4
                  radius: 2
                  color: modelData.isToday ? Theme.background : Theme.accent
                }
              }
            }
          }
          Text { Layout.fillWidth: true; text: "Upcoming"; color: Theme.muted; font.family: Theme.font; font.bold: true }
          ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
            model: root.upcomingEvents(6)
            delegate: Rectangle {
              required property var modelData
              width: ListView.view.width
              implicitHeight: 44
              radius: 9
              color: Theme.surface
              RowLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 10
                ColumnLayout {
                  spacing: 0
                  Text { text: Qt.formatDateTime(new Date(modelData.date + "T00:00:00"), "dd"); color: Theme.accent; font.family: Theme.font; font.pixelSize: 18; font.bold: true }
                  Text { text: Qt.formatDateTime(new Date(modelData.date + "T00:00:00"), "MMM"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
                }
                Text { text: modelData.title; color: Theme.text; font.family: Theme.font; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { visible: modelData.allDay; text: "all day"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
              }
            }
          }
          Rectangle {
            Layout.fillWidth: true; implicitHeight: 42; radius: 9; color: Theme.surface
            Text { anchors.centerIn: parent; text: "Open Obsidian"; color: Theme.accent; font.family: Theme.font }
            MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["obsidian"]) }
          }
        }
      }
      Keys.onEscapePressed: root.widgetVisible = false
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
