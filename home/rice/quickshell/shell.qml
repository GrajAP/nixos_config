//@ pragma UseQApplication

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
  property bool trayExpanded: false
  property bool toolStatusVisible: false
  property bool toolBusy: false
  property string toolStatusTitle: ""
  property string toolStatusDetail: ""
  property string screenshotPath: ""
  property bool screenshotOpenAfterCapture: false
  property var screenshotStrokes: []
  property var screenshotCurrentStroke: null
  property string screenshotInk: "#ff4d6d"
  property int screenshotInkWidth: 5
  property bool widgetVisible: false
  property string widgetPage: "audio"
  property string networkStatus: "Loading…"
  property bool wifiEnabled: true
  property var wifiNetworks: []
  property var weatherData: null
  property var calendarEvents: []
  property int calendarMonthOffset: 0
  property string calendarSelectedDate: Qt.formatDateTime(clock.date, "yyyy-MM-dd")
  readonly property var mediaPlayer: Mpris.players.values.find(player => player.identity.toLowerCase().includes("spotify")) || null
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
  IpcHandler {
    target: "tools"
    function screenshotEdit(): void { root.captureScreenshot("edit", true); }
    function screenshotCopy(): void { root.captureScreenshot("copy", false); }
    function screenshotSave(): void { root.captureScreenshot("save", false); }
    function voiceStart(): void { root.runTool(["@voiceTool@", "start"], "Voice to text", "Recording… release Pause to transcribe"); }
    function voiceStop(): void { root.runTool(["@voiceTool@", "stop"], "Voice to text", "Transcribing and typing…"); }
  }
  Timer { id: osdTimer; interval: 1200; onTriggered: root.osdVisible = false }
  Timer { id: toolStatusTimer; interval: 1800; onTriggered: root.toolStatusVisible = root.toolBusy }
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
  Process {
    id: screenshotAction
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n").filter(line => line.length > 0);
        const path = lines.length > 0 ? lines[lines.length - 1] : "";
        if (path.length > 0) {
          root.screenshotPath = path;
          root.screenshotStrokes = [];
          root.screenshotCurrentStroke = null;
          if (root.screenshotOpenAfterCapture) root.openWidget("screenshot");
        }
      }
    }
    onExited: {
      root.toolBusy = false;
      toolStatusTimer.restart();
      root.screenshotOpenAfterCapture = false;
    }
  }
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
  function runTool(command, title, detail) {
    root.toolBusy = true;
    root.toolStatusVisible = true;
    root.toolStatusTitle = title;
    root.toolStatusDetail = detail;
    toolStatusTimer.stop();
    Quickshell.execDetached(command);
    root.toolBusy = false;
    toolStatusTimer.restart();
  }
  function runWidgetTool(command, title, detail) {
    root.widgetVisible = false;
    Qt.callLater(() => root.runTool(command, title, detail));
  }
  function captureScreenshot(mode, openAfter) {
    root.widgetVisible = false;
    root.screenshotOpenAfterCapture = openAfter;
    root.toolBusy = true;
    root.toolStatusVisible = true;
    root.toolStatusTitle = "Screenshot";
    root.toolStatusDetail = mode === "edit" ? "Select an area for preview" : (mode === "copy" ? "Select an area to copy" : "Select an area to save");
    toolStatusTimer.stop();
    Qt.callLater(() => screenshotAction.exec(["@screenshotTool@", mode]));
  }
  function screenshotEditedArgs(action) {
    return ["@screenshotTool@", action, root.screenshotPath, JSON.stringify(root.screenshotStrokes)];
  }
  function screenshotDisplayRect(canvas, image) {
    const paintedWidth = image.paintedWidth || canvas.width;
    const paintedHeight = image.paintedHeight || canvas.height;
    return {
      x: (canvas.width - paintedWidth) / 2,
      y: (canvas.height - paintedHeight) / 2,
      width: paintedWidth,
      height: paintedHeight
    };
  }
  function screenshotPointFromCanvas(mouse, canvas, image) {
    if (root.screenshotPath.length === 0 || image.sourceSize.width <= 0 || image.sourceSize.height <= 0)
      return null;
    const rect = root.screenshotDisplayRect(canvas, image);
    if (mouse.x < rect.x || mouse.y < rect.y || mouse.x > rect.x + rect.width || mouse.y > rect.y + rect.height)
      return null;
    return {
      x: Math.max(0, Math.min(image.sourceSize.width, (mouse.x - rect.x) / rect.width * image.sourceSize.width)),
      y: Math.max(0, Math.min(image.sourceSize.height, (mouse.y - rect.y) / rect.height * image.sourceSize.height))
    };
  }
  function screenshotDrawStroke(context, stroke, canvas, image) {
    if (!stroke || !stroke.points || stroke.points.length === 0 || image.sourceSize.width <= 0 || image.sourceSize.height <= 0)
      return;
    const rect = root.screenshotDisplayRect(canvas, image);
    context.strokeStyle = stroke.color || root.screenshotInk;
    context.fillStyle = stroke.color || root.screenshotInk;
    context.lineWidth = Math.max(1, (stroke.width || root.screenshotInkWidth) * rect.width / image.sourceSize.width);
    context.lineCap = "round";
    context.lineJoin = "round";
    context.beginPath();
    for (let index = 0; index < stroke.points.length; index++) {
      const point = stroke.points[index];
      const x = rect.x + point.x / image.sourceSize.width * rect.width;
      const y = rect.y + point.y / image.sourceSize.height * rect.height;
      if (index === 0) context.moveTo(x, y);
      else context.lineTo(x, y);
    }
    if (stroke.points.length === 1) {
      const point = stroke.points[0];
      const x = rect.x + point.x / image.sourceSize.width * rect.width;
      const y = rect.y + point.y / image.sourceSize.height * rect.height;
      context.arc(x, y, context.lineWidth / 2, 0, Math.PI * 2);
      context.fill();
    } else {
      context.stroke();
    }
  }
  function dateKey(date) {
    return Qt.formatDateTime(date, "yyyy-MM-dd");
  }
  function calendarDisplayDate() {
    return new Date(clock.date.getFullYear(), clock.date.getMonth() + root.calendarMonthOffset, 1);
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
    const displayedDate = calendarDisplayDate();
    const year = displayedDate.getFullYear();
    const month = displayedDate.getMonth();
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
        cells.push({ inMonth: false, day: 0, date: "", isToday: false, isSelected: false, eventCount: 0 });
        continue;
      }
      const cellDate = new Date(year, month, day);
      const key = dateKey(cellDate);
      cells.push({
        inMonth: true,
        day,
        date: key,
        isToday: key === today,
        isSelected: key === root.calendarSelectedDate,
        eventCount: counts[key] || 0
      });
    }
    return cells;
  }
  function upcomingEvents(limit, fromDate) {
    const firstDate = fromDate || dateKey(clock.date);
    return root.calendarEvents
      .filter(event => event.date >= firstDate)
      .slice()
      .sort((a, b) => a.date.localeCompare(b.date) || a.title.localeCompare(b.title))
      .slice(0, limit || 10);
  }
  function nextEventSummary() {
    const events = upcomingEvents(1);
    if (events.length === 0) return "No upcoming events";
    const event = events[0];
    const date = Qt.formatDateTime(new Date(event.date + "T00:00:00"), "ddd, d MMM");
    const time = event.allDay ? "all day" : (event.startTime || "");
    return date + (time ? " · " + time : "") + "\n" + event.title;
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
          model: ScriptModel {
            values: Hyprland.workspaces.values
              .filter(workspace => workspace.id > 0)
              .sort((a, b) => a.id - b.id)
          }
          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 34
            radius: 7
            color: modelData.active ? Theme.accent : "transparent"
            Text {
              anchors.centerIn: parent
              text: root.numerals[parent.modelData.id] || parent.modelData.id
              color: parent.color === Theme.accent ? Theme.background : Theme.text
              font.family: Theme.font
              font.pixelSize: 14
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Hyprland.dispatch("workspace " + parent.modelData.id)
            }
          }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 30
          radius: 7
          color: root.trayExpanded ? Theme.surface : "transparent"
          border.color: root.trayExpanded ? Theme.accent : "transparent"
          Text {
            anchors.centerIn: parent
            text: root.trayExpanded ? "󰅀" : "󰅂"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 16
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.trayExpanded = !root.trayExpanded
          }
        }

        ColumnLayout {
          visible: root.trayExpanded
          Layout.fillWidth: true
          spacing: 7

          Repeater {
            model: SystemTray.items
            IconImage {
              required property var modelData
              Layout.alignment: Qt.AlignHCenter
              implicitSize: 20
              source: modelData.icon
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
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
            cursorShape: Qt.PointingHandCursor
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
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openWidget("network") }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: ""
          color: root.mediaPlayer ? Theme.text : Theme.muted
          font.family: Theme.font; font.pixelSize: 17
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openWidget("media") }
        }

        Item {
          Layout.alignment: Qt.AlignHCenter
          implicitWidth: 32
          implicitHeight: 31
          ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: root.weatherGlyph()
              color: Theme.text
              font.family: Theme.font
              font.pixelSize: 17
            }
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: root.weatherData && root.weatherData.temperature !== null && root.weatherData.temperature !== undefined ? Math.round(root.weatherData.temperature) + "°" : "—"
              color: Theme.muted
              font.family: Theme.font
              font.pixelSize: 10
              font.bold: true
            }
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openWidget("weather") }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "󰄀"
          color: root.toolBusy ? Theme.accent : Theme.text
          font.family: Theme.font
          font.pixelSize: 17
          MouseArea {
            id: toolsMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openWidget("tools")
          }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: notificationServer.trackedNotifications.values.length > 0 ? "󰂚" : "󰂜"
          color: Theme.text; font.family: Theme.font; font.pixelSize: 16
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.notificationHistoryVisible = !root.notificationHistoryVisible }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: Qt.formatDateTime(clock.date, "HH\nmm")
          horizontalAlignment: Text.AlignHCenter
          lineHeight: 0.82
          color: Theme.text
          font.family: Theme.font
          font.pixelSize: 11
          font.bold: true
          MouseArea {
            id: clockMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openWidget("calendar")
          }
        }
      }
    }
  }

  PanelWindow {
    id: widgetWindow
    visible: root.widgetVisible
    focusable: true
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    margins.right: 44
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      onClicked: mouse => {
        const point = mapToItem(widgetPanel, mouse.x, mouse.y);
        if (point.x < 0 || point.y < 0 || point.x > widgetPanel.width || point.y > widgetPanel.height)
          root.widgetVisible = false;
      }
    }

    Rectangle {
      id: widgetPanel
      width: Math.min(460, parent.width - 20)
      height: Math.min(720, parent.height - 36)
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: 10
      anchors.bottomMargin: 18
      radius: 16
      color: Theme.background
      border.color: Theme.accent
      border.width: 2
      focus: root.widgetVisible
      ColumnLayout {
        anchors.fill: parent; anchors.margins: 18; spacing: 12
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: ({audio: "Audio", network: "Network", media: "Spotify", weather: "Weather", calendar: "Calendar", tools: "Tools", screenshot: "Screenshot"})[root.widgetPage]
            color: Theme.text; font.family: Theme.font; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true
          }
          Text { text: "×"; color: Theme.muted; font.pixelSize: 22; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.widgetVisible = false } }
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
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted }
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
            Layout.fillWidth: true; Layout.preferredHeight: 170; spacing: 6; clip: true
            model: ScriptModel { values: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream) }
            delegate: Rectangle {
              required property var modelData
              width: ListView.view.width; height: 42; radius: 9
              color: modelData === Pipewire.defaultAudioSink ? Theme.accent : Theme.surface
              Text { anchors.fill: parent; anchors.margins: 10; verticalAlignment: Text.AlignVCenter; text: parent.modelData.description || parent.modelData.nickname || parent.modelData.name; color: parent.modelData === Pipewire.defaultAudioSink ? Theme.background : Theme.text; font.family: Theme.font; elide: Text.ElideRight }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Pipewire.preferredDefaultAudioSink = parent.modelData }
            }
          }
          Text { text: "Microphones"; color: Theme.muted; font.family: Theme.font; font.bold: true }
          Text {
            text: Pipewire.defaultAudioSource ? (Pipewire.defaultAudioSource.description || Pipewire.defaultAudioSource.name) : "No input"
            color: Theme.text; font.family: Theme.font; wrapMode: Text.Wrap; Layout.fillWidth: true
          }
          RowLayout {
            Layout.fillWidth: true
            Text {
              text: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio && Pipewire.defaultAudioSource.audio.muted ? "󰍭" : "󰍬"
              color: Theme.accent; font.family: Theme.font; font.pixelSize: 22
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted }
            }
            Slider {
              Layout.fillWidth: true; from: 0; to: 1.5
              value: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.volume : 0
              onMoved: if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.volume = value
            }
            Text { text: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Math.round(Pipewire.defaultAudioSource.audio.volume * 100) + "%" : "0%"; color: Theme.text; font.family: Theme.font }
          }
          ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6; clip: true
            model: ScriptModel { values: Pipewire.nodes.values.filter(node => node.audio && node.isSource && !node.isStream) }
            delegate: Rectangle {
              required property var modelData
              width: ListView.view.width; height: 42; radius: 9
              color: modelData === Pipewire.defaultAudioSource ? Theme.accent : Theme.surface
              Text { anchors.fill: parent; anchors.margins: 10; verticalAlignment: Text.AlignVCenter; text: parent.modelData.description || parent.modelData.nickname || parent.modelData.name; color: parent.modelData === Pipewire.defaultAudioSource ? Theme.background : Theme.text; font.family: Theme.font; elide: Text.ElideRight }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Pipewire.preferredDefaultAudioSource = parent.modelData }
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
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { networkAction.exec(["nmcli", "device", "wifi", "rescan"]); wifiScan.running = true; } }
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
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!parent.modelData.active) networkAction.exec(["nmcli", "connection", "up", "id", parent.modelData.ssid]) }
            }
          }
        }

        ColumnLayout {
          visible: root.widgetPage === "media"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
          Image { visible: root.mediaPlayer !== null; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 220; Layout.preferredHeight: 220; fillMode: Image.PreserveAspectCrop; source: root.mediaPlayer ? root.mediaPlayer.trackArtUrl : "" }
          Text { visible: root.mediaPlayer === null; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 70; text: ""; color: Theme.accent; font.family: Theme.font; font.pixelSize: 82 }
          Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.mediaPlayer ? (root.mediaPlayer.trackTitle || "Unknown title") : "Spotify is not running"; color: Theme.text; font.family: Theme.font; font.bold: true; font.pixelSize: 17; wrapMode: Text.Wrap }
          Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.mediaPlayer ? root.mediaPlayer.trackArtist : ""; color: Theme.muted; font.family: Theme.font }
          RowLayout {
            visible: root.mediaPlayer !== null; Layout.alignment: Qt.AlignHCenter; spacing: 28
            Text { text: "󰒮"; color: Theme.text; font.family: Theme.font; font.pixelSize: 25; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.mediaPlayer && root.mediaPlayer.canGoPrevious) root.mediaPlayer.previous() } }
            Text { text: root.mediaPlayer && root.mediaPlayer.isPlaying ? "󰏤" : "󰐊"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 30; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.mediaPlayer && root.mediaPlayer.canTogglePlaying) root.mediaPlayer.togglePlaying() } }
            Text { text: "󰒭"; color: Theme.text; font.family: Theme.font; font.pixelSize: 25; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.mediaPlayer && root.mediaPlayer.canGoNext) root.mediaPlayer.next() } }
          }
          Rectangle {
            visible: root.mediaPlayer === null
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 8
            color: Theme.surface
            Text { anchors.centerIn: parent; text: "  Open Spotify"; color: Theme.accent; font.family: Theme.font }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["spotify"]) }
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
          visible: root.widgetPage === "tools"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
          Text { text: "Screenshot"; color: Theme.muted; font.family: Theme.font; font.bold: true }
          Rectangle {
            Layout.fillWidth: true; implicitHeight: 44; radius: 9; color: Theme.surface
            Text { anchors.centerIn: parent; text: "󰄀  Select area and edit"; color: Theme.text; font.family: Theme.font }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.captureScreenshot("edit", true) }
          }
          Rectangle {
            Layout.fillWidth: true; implicitHeight: 44; radius: 9; color: Theme.surface
            Text { anchors.centerIn: parent; text: "󰆏  Select area and copy"; color: Theme.text; font.family: Theme.font }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.captureScreenshot("copy", false) }
          }
          Rectangle {
            Layout.fillWidth: true; implicitHeight: 44; radius: 9; color: Theme.surface
            Text { anchors.centerIn: parent; text: "󰈔  Select area, save and copy"; color: Theme.text; font.family: Theme.font }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.captureScreenshot("save", false) }
          }

          Text { text: "Voice to text"; color: Theme.muted; font.family: Theme.font; font.bold: true; Layout.topMargin: 8 }
          Rectangle {
            Layout.fillWidth: true; implicitHeight: 44; radius: 9; color: root.toolBusy ? Theme.accent : Theme.surface
            Text { anchors.centerIn: parent; text: "󰍬  Start recording"; color: root.toolBusy ? Theme.background : Theme.text; font.family: Theme.font }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runWidgetTool(["@voiceTool@", "start"], "Voice to text", "Recording… press Stop or release Pause") }
          }
          Rectangle {
            Layout.fillWidth: true; implicitHeight: 44; radius: 9; color: Theme.surface
            Text { anchors.centerIn: parent; text: "󰓛  Stop and transcribe"; color: Theme.text; font.family: Theme.font }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runWidgetTool(["@voiceTool@", "stop"], "Voice to text", "Transcribing and typing…") }
          }
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "transparent"
            border.color: Theme.surface
            Text {
              anchors.fill: parent
              anchors.margins: 14
              text: "Keys now call Quickshell IPC:\nPrint → edit screenshot\nSuper+S → copy screenshot\nSuper+Shift+S → save screenshot\nPause hold → voice recording"
              color: Theme.muted
              font.family: Theme.font
              wrapMode: Text.Wrap
            }
          }
        }

        ColumnLayout {
          visible: root.widgetPage === "screenshot"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: Theme.surface
            clip: true
            Image {
              id: screenshotImage
              anchors.fill: parent
              anchors.margins: 10
              source: root.screenshotPath.length > 0 ? "file://" + root.screenshotPath : ""
              fillMode: Image.PreserveAspectFit
              cache: false
              onStatusChanged: screenshotCanvas.requestPaint()
            }
            Canvas {
              id: screenshotCanvas
              anchors.fill: parent
              anchors.margins: 10
              visible: root.screenshotPath.length > 0
              onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, height);
                for (const stroke of root.screenshotStrokes)
                  root.screenshotDrawStroke(context, stroke, screenshotCanvas, screenshotImage);
                root.screenshotDrawStroke(context, root.screenshotCurrentStroke, screenshotCanvas, screenshotImage);
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                enabled: root.screenshotPath.length > 0
                onPressed: mouse => {
                  const point = root.screenshotPointFromCanvas(mouse, screenshotCanvas, screenshotImage);
                  if (!point) return;
                  root.screenshotCurrentStroke = {
                    color: root.screenshotInk,
                    width: root.screenshotInkWidth,
                    points: [point]
                  };
                  screenshotCanvas.requestPaint();
                }
                onPositionChanged: mouse => {
                  if (!root.screenshotCurrentStroke) return;
                  const point = root.screenshotPointFromCanvas(mouse, screenshotCanvas, screenshotImage);
                  if (!point) return;
                  root.screenshotCurrentStroke.points.push(point);
                  screenshotCanvas.requestPaint();
                }
                onReleased: {
                  if (!root.screenshotCurrentStroke) return;
                  root.screenshotStrokes = root.screenshotStrokes.concat([root.screenshotCurrentStroke]);
                  root.screenshotCurrentStroke = null;
                  screenshotCanvas.requestPaint();
                }
                onCanceled: {
                  root.screenshotCurrentStroke = null;
                  screenshotCanvas.requestPaint();
                }
              }
            }
            Text {
              visible: root.screenshotPath.length === 0
              anchors.centerIn: parent
              text: "No screenshot yet"
              color: Theme.muted
              font.family: Theme.font
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
              Layout.fillWidth: true; implicitHeight: 40; radius: 9; color: Theme.surface
              Text { anchors.centerIn: parent; text: "Copy"; color: Theme.text; font.family: Theme.font }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.screenshotPath.length > 0) root.runTool(root.screenshotEditedArgs("copy-edited"), "Screenshot", "Copied edited image") }
            }
            Rectangle {
              Layout.fillWidth: true; implicitHeight: 40; radius: 9; color: Theme.surface
              Text { anchors.centerIn: parent; text: "Save"; color: Theme.text; font.family: Theme.font }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.screenshotPath.length > 0) root.runTool(root.screenshotEditedArgs("save-edited"), "Screenshot", "Saved edited image") }
            }
            Rectangle {
              Layout.fillWidth: true; implicitHeight: 40; radius: 9; color: Theme.surface
              Text { anchors.centerIn: parent; text: "Retake"; color: Theme.accent; font.family: Theme.font }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.captureScreenshot("edit", true) }
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
              Layout.fillWidth: true; implicitHeight: 36; radius: 9; color: Theme.surface
              Text { anchors.centerIn: parent; text: "Undo"; color: Theme.text; font.family: Theme.font }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.screenshotStrokes.length > 0) {
                    root.screenshotStrokes = root.screenshotStrokes.slice(0, root.screenshotStrokes.length - 1);
                    screenshotCanvas.requestPaint();
                  }
                }
              }
            }
            Rectangle {
              Layout.fillWidth: true; implicitHeight: 36; radius: 9; color: Theme.surface
              Text { anchors.centerIn: parent; text: "Clear"; color: Theme.text; font.family: Theme.font }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.screenshotStrokes = [];
                  root.screenshotCurrentStroke = null;
                  screenshotCanvas.requestPaint();
                }
              }
            }
          }
        }

        ColumnLayout {
          visible: root.widgetPage === "calendar"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
          RowLayout {
            Layout.fillWidth: true
            Text {
              text: "‹"
              color: Theme.text
              font.pixelSize: 28
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.calendarMonthOffset--
              }
            }
            Text {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              text: Qt.formatDateTime(root.calendarDisplayDate(), "MMMM yyyy")
              color: Theme.text
              font.family: Theme.font
              font.pixelSize: 18
              font.bold: true
            }
            Text {
              text: "›"
              color: Theme.text
              font.pixelSize: 28
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.calendarMonthOffset++
              }
            }
          }
          RowLayout {
            Layout.fillWidth: true
            Text {
              text: Qt.formatDateTime(new Date(root.calendarSelectedDate + "T00:00:00"), "dddd, d MMMM")
              color: Theme.muted
              font.family: Theme.font
              Layout.fillWidth: true
            }
            Rectangle {
              implicitWidth: 70
              implicitHeight: 28
              radius: 7
              color: Theme.surface
              Text { anchors.centerIn: parent; text: "Today"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 11 }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.calendarMonthOffset = 0;
                  root.calendarSelectedDate = root.dateKey(clock.date);
                }
              }
            }
          }
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
                color: !modelData.inMonth ? "transparent" : modelData.isSelected ? Theme.accent : Theme.surface
                border.color: modelData.inMonth && (modelData.isToday || modelData.eventCount > 0) && !modelData.isSelected ? Theme.accent : "transparent"
                border.width: modelData.inMonth && (modelData.isToday || modelData.eventCount > 0) && !modelData.isSelected ? 1 : 0
                Text {
                  anchors.centerIn: parent
                  text: modelData.inMonth ? modelData.day : ""
                  color: modelData.isSelected ? Theme.background : Theme.text
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
                  color: modelData.isSelected ? Theme.background : Theme.accent
                }
                MouseArea {
                  anchors.fill: parent
                  enabled: modelData.inMonth
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: root.calendarSelectedDate = modelData.date
                }
              }
            }
          }
          Text {
            Layout.fillWidth: true
            text: "Events from " + Qt.formatDateTime(new Date(root.calendarSelectedDate + "T00:00:00"), "d MMMM")
            color: Theme.muted
            font.family: Theme.font
            font.bold: true
          }
          ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
            model: root.upcomingEvents(10, root.calendarSelectedDate)
            delegate: Rectangle {
              required property var modelData
              width: ListView.view.width
              implicitHeight: 50
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
                Text {
                  text: modelData.allDay ? "all day" : (modelData.startTime || "")
                  color: Theme.muted
                  font.family: Theme.font
                  font.pixelSize: 10
                }
              }
            }
          }
          Rectangle {
            Layout.fillWidth: true; implicitHeight: 42; radius: 9; color: Theme.surface
            Text { anchors.centerIn: parent; text: "Open Obsidian"; color: Theme.accent; font.family: Theme.font }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["obsidian"]) }
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
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.notificationPopupVisible = false }
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
    visible: root.toolStatusVisible
    color: "transparent"
    implicitWidth: 330
    implicitHeight: 78
    anchors { bottom: true }
    margins.bottom: 144
    exclusionMode: ExclusionMode.Ignore
    Rectangle {
      anchors.fill: parent
      radius: 14
      color: Theme.background
      border.color: root.toolBusy ? Theme.accent : Theme.surface
      border.width: 2
      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        Text {
          text: root.toolStatusTitle === "Voice to text" ? "󰍬" : "󰄀"
          color: Theme.accent
          font.family: Theme.font
          font.pixelSize: 24
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text { text: root.toolStatusTitle; color: Theme.text; font.family: Theme.font; font.bold: true }
          Text { text: root.toolStatusDetail; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
        }
      }
    }
  }

  PanelWindow {
    visible: root.notificationHistoryVisible
    focusable: true
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    margins.right: 44
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      onClicked: mouse => {
        const point = mapToItem(notificationPanel, mouse.x, mouse.y);
        if (point.x < 0 || point.y < 0 || point.x > notificationPanel.width || point.y > notificationPanel.height)
          root.notificationHistoryVisible = false;
      }
    }

    Rectangle {
      id: notificationPanel
      width: Math.min(420, parent.width - 20)
      anchors {
        top: parent.top
        right: parent.right
        bottom: parent.bottom
        topMargin: 18
        rightMargin: 10
        bottomMargin: 18
      }
      radius: 16; color: Theme.background; border.color: Theme.accent; border.width: 2
      ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 10
        RowLayout {
          Layout.fillWidth: true
          Text { text: "Notifications"; color: Theme.text; font.family: Theme.font; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true }
          Text {
            text: "Clear"; color: Theme.accent; font.family: Theme.font
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const copy = notificationServer.trackedNotifications.values.slice(); for (const n of copy) n.dismiss(); } }
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
                Text { text: "×"; color: Theme.muted; font.pixelSize: 18; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.parent.parent.modelData.dismiss() } }
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
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData.invoke() }
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
            MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: appRow.launch() }
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
            { icon: "󰌾", label: "Lock", command: [] },
            { icon: "󰤄", label: "Suspend", command: ["sh", "-c", "sleep 0.3 && systemctl suspend"] },
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
            MouseArea {
              id: powerMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.powerVisible = false;
                if (parent.modelData.label === "Lock" || parent.modelData.label === "Suspend") sessionLock.locked = true;
                if (parent.modelData.command.length > 0) Quickshell.execDetached(parent.modelData.command);
              }
            }
          }
        }
      }
    }
  }
}
