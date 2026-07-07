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
  property bool keybindHelpVisible: false
  property bool notificationPopupVisible: false
  property string hoverWidgetOpenPage: ""
  property string hoverWidgetButtonPage: ""
  property bool hoverWidgetPanelHovered: false
  property bool hoverWidgetMenuOpen: false
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
  property string pendingScreenshotMode: ""
  property bool pendingScreenshotOpenAfterCapture: false
  property bool screenshotCaptureQueued: false
  property var screenshotAnnotations: []
  property var screenshotCurrentStroke: null
  property string screenshotEditMode: "draw"
  property string screenshotTextDraft: ""
  property string screenshotInk: "#ff4d6d"
  property var screenshotInkColors: ["#ff4d6d", "#f59e0b", "#facc15", "#22c55e", "#06b6d4", "#3b82f6", "#a855f7", "#ffffff", "#111827"]
  property int screenshotInkWidth: 5
  property int screenshotTextSize: 32
  property int widgetMotionMs: Theme.motionPanel
  property bool widgetVisible: false
  property bool widgetWindowShown: false
  property string widgetPage: "audio"
  property string weatherForecastMode: "current"
  property string weatherError: ""
  property string weatherLastUpdated: ""
  readonly property color secondaryText: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.72)
  readonly property color faintText: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.48)
  readonly property color elevatedSurface: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.92)
  readonly property color hoverSurface: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
  readonly property color translucentPanel: Qt.rgba(Theme.panel.r, Theme.panel.g, Theme.panel.b, 0.97)
  readonly property color textCursorColor: {
    const surfaceLuma = Theme.surface.r * 0.299 + Theme.surface.g * 0.587 + Theme.surface.b * 0.114
    return surfaceLuma < 0.5 ? Theme.text : Theme.background
  }
  readonly property Component themedCursor: Component {
    Rectangle {
      width: 1
      color: root.textCursorColor
    }
  }
  property int shutdownDelayMinutes: 30
  property string shutdownCustomTarget: ""
  property string shutdownPendingTarget: ""
  property int shutdownRemaining: 0
  property string shutdownStatus: ""
  property var codexUsage: null
  property string codexUsageError: ""
  property bool kanataActive: false
  property bool kanataKnown: false
  property var workspaceEntries: []
  property var workspaceClientsById: ({})
  property var workspaceDragClient: null
  property var workspaceDragTarget: 0
  property var weatherData: null
  property var calendarEvents: []
  property string calendarError: ""
  property var clipboardEntries: []
  property string clipboardFilter: ""
  property string clipboardStatus: ""
  property int calendarMonthOffset: 0
  property string calendarSelectedDate: Qt.formatDateTime(clock.date, "yyyy-MM-dd")
  property string calendarEntryMode: "task"
  property string calendarTitleDraft: ""
  property string calendarStartDraft: ""
  property string calendarEndDraft: ""
  property string calendarEditingHref: ""
  property string calendarEditingKind: ""
  property string keybindHelpFilter: ""
  property string keybindHelpSelectedKey: ""
  property bool calendarCanUndo: false
  property bool calendarAllDay: false
  property int calendarEventStartMinutes: 540
  property int calendarEventDurationMinutes: 60
  property string calendarRepeatAction: ""
  property int calendarRepeatDelta: 0
  readonly property var mediaPlayer: Mpris.players.values.find(player => player.identity.toLowerCase().includes("spotify")) || null
  readonly property var numerals: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
  readonly property var keybindHelpEntries: @keybindHelp@
  readonly property var keyboardMainRows: [
    ["Esc", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"],
    ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "Backspace"],
    ["Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\"],
    ["Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "Enter"],
    ["Shift", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "Shift"],
    ["Ctrl", "Mod", "Alt", "Space", "Alt", "Ctrl"]
  ]
  readonly property var keyboardRows: keyboardMainRows
  readonly property var keyboardNavRows: [
    ["Print", "Scroll", "Pause"],
    ["Ins", "Home", "PgUp"],
    ["Del", "End", "PgDn"]
  ]
  readonly property var keyboardArrowRows: [
    ["", "Up", ""],
    ["Left", "Down", "Right"]
  ]
  readonly property var mouseBindKeys: ["Mouse Left", "Mouse Right", "Wheel Up", "Wheel Down"]
  SystemClock { id: clock; precision: SystemClock.Seconds }

  GlobalShortcut {
    name: "launcher"
    description: "Toggle application launcher"
    onPressed: {
      root.closeWidget();
      root.keybindHelpVisible = false;
      root.powerVisible = false;
      root.launcherVisible = !root.launcherVisible;
    }
  }
  GlobalShortcut {
    name: "notifications"
    description: "Toggle notification history"
    onPressed: {
      root.closeWidget();
      root.keybindHelpVisible = false;
      root.notificationHistoryVisible = !root.notificationHistoryVisible;
    }
  }
  GlobalShortcut {
    name: "keybindHelp"
    description: "Toggle keybind help"
    onPressed: root.toggleKeybindHelp()
  }
  GlobalShortcut {
    name: "clipboardHistory"
    description: "Toggle clipboard history"
    onPressed: root.toggleClipboardHistory()
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
    target: "clipboard"
    function clear(): void { root.runClipboardAction("wipe", null); }
    function toggle(): void { root.toggleClipboardHistory(); }
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
  Timer {
    id: widgetCloseTimer
    interval: root.widgetMotionMs + 30
    repeat: false
    onTriggered: if (!root.widgetVisible) root.widgetWindowShown = false
  }
  Timer {
    interval: 1000
    running: root.widgetVisible && root.widgetPage === "shutdown" && root.shutdownPendingTarget.length > 0
    repeat: true
    onTriggered: root.refreshShutdownStatus()
  }
  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: if (!kanataStatusQuery.running) kanataStatusQuery.running = true
  }
  Timer {
    interval: 1500
    running: true
    repeat: true
    onTriggered: {
      if (!workspaceClientsQuery.running) workspaceClientsQuery.running = true;
      if (!workspaceQuery.running) workspaceQuery.running = true;
    }
  }
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
    id: kanataStatusQuery
    command: ["systemctl", "is-active", "kanata-internalKeyboard.service"]
    stdout: StdioCollector {
      onStreamFinished: {
        const status = text.trim();
        root.kanataActive = status === "active";
        root.kanataKnown = status.length > 0 && status !== "unknown";
      }
    }
  }
  Process {
    id: kanataToggleAction
    command: ["@katanaSwitchTool@"]
    onExited: if (!kanataStatusQuery.running) kanataStatusQuery.running = true
  }
  Process {
    id: workspaceClientsQuery
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const clients = JSON.parse(text);
          const byWorkspace = {};
          for (const client of clients) {
            if (!client || !client.mapped || !client.workspace || client.workspace.id === 0)
              continue;
            const key = String(client.workspace.id);
            if (!byWorkspace[key]) byWorkspace[key] = [];
            byWorkspace[key].push({
              address: client.address || "",
              className: client.class || client.initialClass || "",
              title: client.title || client.initialTitle || "",
              workspaceId: client.workspace.id,
              workspaceName: client.workspace.name || String(client.workspace.id)
            });
          }
          root.workspaceClientsById = byWorkspace;
        } catch (error) {
          root.workspaceClientsById = {};
        }
      }
    }
  }
  Process {
    id: workspaceQuery
    command: ["hyprctl", "workspaces", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const parsed = JSON.parse(text)
            .filter(workspace => workspace && workspace.id !== 0)
            .sort((a, b) => a.id - b.id);
          const byId = {};
          let maxId = 0;
          for (const workspace of parsed) {
            byId[String(workspace.id)] = workspace;
            if (workspace.id > 0)
              maxId = Math.max(maxId, workspace.id);
          }
          const entries = [];
          for (let id = 1; id <= maxId; id++) {
            entries.push(byId[String(id)] || {
              id: id,
              name: String(id),
              windows: 0
            });
          }
          const specialEntries = parsed
            .filter(workspace => workspace.id < 0)
            .sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")));
          for (const workspace of specialEntries)
            entries.push(workspace);
          root.workspaceEntries = entries;
        } catch (error) {
          root.workspaceEntries = [];
        }
      }
    }
  }
  Process {
    id: codexUsageQuery
    command: ["@codexUsageQuery@"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const payload = JSON.parse(text);
          if (!payload || payload.ok === false) {
            root.codexUsage = null;
            root.codexUsageError = payload && payload.error ? payload.error : "Could not read Codex usage";
            return;
          }
          root.codexUsage = payload;
          root.codexUsageError = "";
        } catch (error) {
          root.codexUsage = null;
          root.codexUsageError = "Could not read Codex usage";
        }
      }
    }
  }
  Process {
    id: weatherQuery
    command: ["@weatherQuery@"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const payload = JSON.parse(text);
          if (payload && payload.error) {
            root.weatherData = null;
            root.weatherError = payload.message || payload.description || "Weather unavailable";
          } else {
            root.weatherData = payload;
            root.weatherError = "";
            root.weatherLastUpdated = Qt.formatDateTime(clock.date, "HH:mm");
          }
        } catch (error) {
          root.weatherData = null;
          root.weatherError = "Could not read weather data";
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
          root.calendarError = payload.error || "";
        } catch (error) {
          root.calendarEvents = [];
          root.calendarError = "Could not read calendar data";
        }
      }
    }
  }
  Process {
    id: calendarTaskAction
    property bool succeeded: false
    property string actionName: ""
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const payload = JSON.parse(text);
          calendarTaskAction.succeeded = payload.ok !== false;
          root.calendarError = payload.error || "";
          if (calendarTaskAction.succeeded) root.calendarCanUndo = Boolean(payload.undoable);
        } catch (error) {
          calendarTaskAction.succeeded = true;
        }
      }
    }
    onExited: {
      if (calendarTaskAction.succeeded) root.resetCalendarEditor();
      calendarTaskAction.succeeded = false;
      calendarTaskAction.actionName = "";
      if (calendarQuery.running) {
        calendarQuery.running = false;
        Qt.callLater(() => calendarQuery.running = true);
      } else {
        calendarQuery.running = true;
      }
    }
  }
  Process {
    id: clipboardQuery
    command: ["@clipboardTool@", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.clipboardEntries = JSON.parse(text);
          root.clipboardStatus = root.clipboardEntries.length > 0 ? "" : "Clipboard history is empty";
        } catch (error) {
          root.clipboardEntries = [];
          root.clipboardStatus = "Could not read clipboard history";
        }
      }
    }
  }
  Process {
    id: clipboardAction
    onExited: clipboardQuery.running = true
  }
  Process {
    id: screenshotAction
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n").filter(line => line.length > 0);
        const path = lines.length > 0 ? lines[lines.length - 1] : "";
        if (path.length > 0) {
          if (root.screenshotPath === path)
            root.screenshotPath = "";
          root.screenshotPath = path;
          root.screenshotAnnotations = [];
          root.screenshotCurrentStroke = null;
          if (root.screenshotOpenAfterCapture) root.openWidget("screenshot");
        }
      }
    }
    onExited: {
      root.toolBusy = false;
      toolStatusTimer.restart();
      if (root.screenshotCaptureQueued) {
        root.startScreenshotCapture(root.pendingScreenshotMode, root.pendingScreenshotOpenAfterCapture);
      } else {
        root.screenshotOpenAfterCapture = false;
      }
    }
  }
  Process {
    id: shutdownTimerAction
    stdout: StdioCollector {
      onStreamFinished: root.applyShutdownStatus(text)
    }
  }
  Component.onCompleted: {
    kanataStatusQuery.running = true;
    weatherQuery.running = true;
    calendarQuery.running = true;
    codexUsageQuery.running = true;
    workspaceClientsQuery.running = true;
    workspaceQuery.running = true;
  }
  Timer {
    interval: 15 * 60 * 1000
    running: true
    repeat: true
    onTriggered: weatherQuery.running = true
  }
  Timer {
    interval: 5 * 60 * 1000
    running: true
    repeat: true
    onTriggered: if (!calendarQuery.running) calendarQuery.running = true
  }
  Timer {
    id: calendarTimeRepeatTimer
    interval: 115
    repeat: true
    onTriggered: root.adjustCalendarTime(root.calendarRepeatAction, root.calendarRepeatDelta)
  }
  Timer {
    id: codexUsageTimer
    interval: 4 * 60 * 1000
    running: true
    repeat: true
    onTriggered: if (!codexUsageQuery.running) codexUsageQuery.running = true
  }
  Timer {
    id: hoverWidgetCloseTimer
    interval: 220
    repeat: false
    onTriggered: {
      if (root.hoverWidgetOpenPage.length === 0) return;
      if (!root.widgetVisible || root.widgetPage !== root.hoverWidgetOpenPage) {
        root.hoverWidgetOpenPage = "";
        return;
      }
      if (root.hoverWidgetButtonPage !== root.hoverWidgetOpenPage && !root.hoverWidgetPanelHovered && !root.hoverWidgetMenuOpen) {
        root.closeWidget();
        root.hoverWidgetOpenPage = "";
      }
    }
  }

  function openWidget(page) {
    widgetCloseTimer.stop();
    root.keybindHelpVisible = false;
    root.launcherVisible = false;
    root.powerVisible = false;
    root.notificationHistoryVisible = false;
    widgetWindowShown = true;
    widgetPage = page;
    widgetVisible = true;
    if (page === "weather") weatherQuery.running = true;
    if (page === "calendar") calendarQuery.running = true;
    if (page === "clipboard") clipboardQuery.running = true;
    if (page === "shutdown") root.refreshShutdownStatus();
  }
  function toggleClipboardHistory() {
    root.toggleWidget("clipboard");
  }
  function closeWidget() {
    hoverWidgetCloseTimer.stop();
    root.hoverWidgetOpenPage = "";
    root.hoverWidgetButtonPage = "";
    root.hoverWidgetPanelHovered = false;
    root.hoverWidgetMenuOpen = false;
    widgetVisible = false;
    widgetCloseTimer.restart();
  }
  function toggleWidget(page) {
    if (widgetVisible && widgetPage === page) {
      closeWidget();
      return;
    }
    openWidget(page);
  }
  function showHoverWidget(page) {
    hoverWidgetCloseTimer.stop();
    root.hoverWidgetOpenPage = page;
    root.hoverWidgetButtonPage = page;
    if (root.widgetVisible && root.widgetPage === page) return;
    root.openWidget(page);
    if (page === "codex" && !codexUsageQuery.running)
      codexUsageQuery.running = true;
  }
  function leaveHoverWidgetButton(page) {
    if (root.hoverWidgetButtonPage === page)
      root.hoverWidgetButtonPage = "";
    root.scheduleHoverWidgetClose(page);
  }
  function scheduleHoverWidgetClose(page) {
    if (root.hoverWidgetOpenPage === page && root.widgetVisible && root.widgetPage === page && !root.hoverWidgetMenuOpen)
      hoverWidgetCloseTimer.restart();
  }
  function setHoverWidgetMenuOpen(open) {
    root.hoverWidgetMenuOpen = open;
    if (open)
      hoverWidgetCloseTimer.stop();
    else
      root.scheduleHoverWidgetClose(root.widgetPage);
  }
  function toggleKeybindHelp() {
    const nextVisible = !root.keybindHelpVisible;
    root.closeWidget();
    root.widgetWindowShown = false;
    root.launcherVisible = false;
    root.powerVisible = false;
    root.notificationHistoryVisible = false;
    root.keybindHelpVisible = nextVisible;
    if (nextVisible) {
      root.keybindHelpFilter = "";
      root.keybindHelpSelectedKey = "";
    }
  }
  function toggleCodexUsage() {
    root.toggleWidget("codex");
    codexUsageQuery.running = true;
  }
  function barWidgetActive(page) {
    return root.widgetVisible && root.widgetPage === page;
  }
  function barWidgetBackground(page) {
    return root.barWidgetActive(page) ? Theme.accentSoft : "transparent";
  }
  function barWidgetBorder(page) {
    return root.barWidgetActive(page) ? Theme.accent : "transparent";
  }
  function barWidgetText(page, inactiveColor) {
    return root.barWidgetActive(page) ? Theme.accent : inactiveColor;
  }
  function appIconForClient(client) {
    const value = String((client && (client.className || client.title)) || "").toLowerCase();
    if (value.includes("firefox")) return "󰈹";
    if (value.includes("chromium") || value.includes("chrome") || value.includes("brave")) return "";
    if (value.includes("helium")) return "";
    if (value.includes("spotify")) return "";
    if (value.includes("discord") || value.includes("vesktop")) return "󰙯";
    if (value.includes("signal")) return "󰭹";
    if (value.includes("obsidian")) return "󰠮";
    if (value.includes("code") || value.includes("codium") || value.includes("t3code")) return "󰨞";
    if (value.includes("kitty") || value.includes("wezterm") || value.includes("alacritty") || value.includes("foot")) return "";
    if (value.includes("steam")) return "";
    if (value.includes("obs")) return "󰻂";
    if (value.includes("ferdium")) return "󰭻";
    if (value.includes("org.gnome.nautilus") || value.includes("dolphin") || value.includes("nemo")) return "󰉋";
    return "󰘔";
  }
  function appThemeIconForClient(client) {
    const value = String((client && (client.className || client.title)) || "").toLowerCase();
    if (value.includes("firefox")) return "firefox";
    if (value.includes("chromium")) return "chromium";
    if (value.includes("chrome")) return "google-chrome";
    if (value.includes("brave")) return "brave-browser";
    if (value.includes("helium")) return "helium";
    if (value.includes("spotify")) return "spotify";
    if (value.includes("vesktop") || value.includes("discord")) return "discord";
    if (value.includes("signal")) return "signal-desktop";
    if (value.includes("obsidian")) return "obsidian";
    if (value.includes("codium")) return "vscodium";
    if (value.includes("t3code")) return "t3code";
    if (value.includes("code")) return "visual-studio-code";
    if (value.includes("kitty")) return "kitty";
    if (value.includes("wezterm")) return "org.wezfurlong.wezterm";
    if (value.includes("alacritty")) return "Alacritty";
    if (value.includes("foot")) return "foot";
    if (value.includes("steam")) return "steam";
    if (value.includes("obs")) return "com.obsproject.Studio";
    if (value.includes("ferdium")) return "ferdium";
    if (value.includes("dolphin")) return "system-file-manager";
    if (value.includes("org.gnome.nautilus")) return "org.gnome.Nautilus";
    if (value.includes("nemo")) return "nemo";
    return "application-x-executable";
  }
  function appIconSourceForClient(client) {
    const value = String((client && (client.className || client.title)) || "").toLowerCase();
    if (value.includes("helium")) return "file:///etc/profiles/per-user/grajpap/share/icons/hicolor/256x256/apps/helium.png";
    if (value.includes("nemo")) return "file:///etc/profiles/per-user/grajpap/share/icons/hicolor/scalable/apps/nemo.svg";
    if (value.includes("t3code")) return "file:///etc/profiles/per-user/grajpap/share/icons/hicolor/scalable/apps/t3code.svg";
    return Quickshell.iconPath(root.appThemeIconForClient(client), "application-x-executable");
  }
  function appIconSizeForClient(client, normalSize) {
    const value = String((client && (client.className || client.title)) || "").toLowerCase();
    if (value.includes("t3code")) return Math.max(14, normalSize - 5);
    if (value.includes("helium")) return Math.max(16, normalSize - 3);
    return normalSize;
  }
  function appColorForClient(client) {
    const value = String((client && (client.className || client.title)) || "").toLowerCase();
    if (value.includes("firefox")) return "#f97316";
    if (value.includes("chromium") || value.includes("chrome") || value.includes("brave") || value.includes("helium")) return "#60a5fa";
    if (value.includes("spotify")) return "#22c55e";
    if (value.includes("discord") || value.includes("vesktop")) return "#8b5cf6";
    if (value.includes("signal")) return "#38bdf8";
    if (value.includes("obsidian")) return "#a78bfa";
    if (value.includes("code") || value.includes("codium") || value.includes("t3code")) return "#3b82f6";
    if (value.includes("kitty") || value.includes("wezterm") || value.includes("alacritty") || value.includes("foot")) return "#64748b";
    if (value.includes("steam")) return "#1d4ed8";
    if (value.includes("obs")) return "#7c3aed";
    if (value.includes("ferdium")) return "#f59e0b";
    if (value.includes("org.gnome.nautilus") || value.includes("dolphin") || value.includes("nemo")) return "#06b6d4";
    return Theme.surfaceAlt;
  }
  function workspaceClientList(workspaceId, limit) {
    return (root.workspaceClientsById[String(workspaceId)] || []).slice(0, limit);
  }
  function workspaceClientIcons(workspaceId, limit) {
    const clients = root.workspaceClientsById[String(workspaceId)] || [];
    const icons = [];
    for (const client of clients) {
      const icon = root.appIconForClient(client);
      if (!icons.includes(icon)) icons.push(icon);
      if (icons.length >= limit) break;
    }
    return icons;
  }
  function workspaceIds() {
    return root.workspaceEntries.map(workspace => workspace.id);
  }
  function workspaceEntryById(workspaceId) {
    const key = String(workspaceId);
    for (const workspace of root.workspaceEntries) {
      if (String(workspace.id) === key)
        return workspace;
    }
    return null;
  }
  function workspaceDispatchName(workspaceId) {
    const workspace = root.workspaceEntryById(workspaceId);
    return workspace && workspace.name ? String(workspace.name) : String(workspaceId);
  }
  function workspaceIsSpecial(workspaceId) {
    return root.workspaceDispatchName(workspaceId).indexOf("special:") === 0;
  }
  function specialWorkspaceName(workspaceId) {
    const name = root.workspaceDispatchName(workspaceId);
    return name.indexOf("special:") === 0 ? name.slice(8) : name;
  }
  function openWorkspace(workspaceId) {
    root.closeTransientPanels();
    root.clearWorkspaceInteraction();
    if (root.workspaceIsSpecial(workspaceId))
      Quickshell.execDetached(["toggle-special-workspace", root.specialWorkspaceName(workspaceId)]);
    else
      Hyprland.dispatch("workspace " + root.workspaceDispatchName(workspaceId));
  }
  function workspaceDisplayName(workspaceId) {
    const name = root.workspaceDispatchName(workspaceId);
    return name.indexOf("special:") === 0 ? name.slice(8) : name;
  }
  function workspaceCellHeight(workspaceId) {
    const clients = root.workspaceClientsById[String(workspaceId)] || [];
    if (clients.length === 0) return 34;
    return Math.min(220, 24 + Math.min(clients.length, 5) * 30 + (clients.length > 5 ? 26 : 0));
  }
  function workspaceIdAtY(y) {
    const workspaces = root.workspaceEntries;
    const spacing = 7;
    let top = 0;
    for (const workspace of workspaces) {
      const cellHeight = root.workspaceCellHeight(workspace.id);
      if (y >= top && y <= top + cellHeight)
        return workspace.id;
      top += cellHeight + spacing;
    }
    return 0;
  }
  function clearWorkspaceInteraction() {
    root.workspaceDragClient = null;
    root.workspaceDragTarget = 0;
  }
  function moveWorkspaceClient(client, workspaceId) {
    if (!client || !client.address || workspaceId === 0 || client.workspaceId === workspaceId) {
      root.clearWorkspaceInteraction();
      return;
    }
    Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspacesilent", root.workspaceDispatchName(workspaceId) + ",address:" + client.address]);
    if (root.workspaceIsSpecial(workspaceId))
      Quickshell.execDetached(["sync-special-workspaces-monitor"]);
    root.clearWorkspaceInteraction();
    Qt.callLater(() => {
      if (!workspaceClientsQuery.running) workspaceClientsQuery.running = true;
      if (!workspaceQuery.running) workspaceQuery.running = true;
    });
  }
  function refreshCodexUsage() {
    if (!codexUsageQuery.running) codexUsageQuery.running = true;
  }
  function closeTransientPanels() {
    root.closeWidget();
    root.launcherVisible = false;
    root.powerVisible = false;
    root.notificationHistoryVisible = false;
    root.keybindHelpVisible = false;
  }
  function keybindHelpCategories() {
    const categories = [];
    for (const entry of root.keybindHelpEntries) {
      if (!categories.includes(entry.category))
        categories.push(entry.category);
    }
    return categories;
  }
  function keybindsInCategory(category) {
    return root.keybindHelpEntries.filter(entry => entry.category === category);
  }
  function keybindMatchesKey(entry, key) {
    if (!entry || !entry.combo || !key) return false;
    const combo = String(entry.combo).toUpperCase();
    const label = String(key).toUpperCase();
    if (label === "MOD") return combo.includes("MOD");
    if (label === "CTRL") return combo.includes("CTRL");
    if (label === "ALT") return combo.includes("ALT");
    if (label === "SHIFT") return combo.includes("SHIFT");
    if (label === "SPACE") return combo.includes("SPACE");
    if (label === "ENTER") return combo.includes("ENTER");
    if (label === "PRINT") return combo.includes("PRINT");
    if (label === "PAUSE") return combo.includes("PAUSE");
    if (label === "MOUSE LEFT" || label === "MOUSE RIGHT" || label === "WHEEL UP" || label === "WHEEL DOWN")
      return combo.includes(label);
    return combo.split(",").map(part => part.trim().toUpperCase()).includes(label);
  }
  function keybindsForKey(key) {
    return root.keybindHelpEntries.filter(entry => root.keybindMatchesKey(entry, key));
  }
  function filteredKeybindHelpEntries() {
    const query = root.keybindHelpFilter.trim().toLowerCase();
    if (query.length === 0) return root.keybindHelpEntries;
    return root.keybindHelpEntries.filter(entry =>
      String(entry.combo || "").toLowerCase().includes(query) ||
      String(entry.description || "").toLowerCase().includes(query) ||
      String(entry.category || "").toLowerCase().includes(query));
  }
  function keybindHelpFilteredCategories() {
    const categories = [];
    for (const entry of root.filteredKeybindHelpEntries()) {
      if (!categories.includes(entry.category))
        categories.push(entry.category);
    }
    return categories;
  }
  function filteredKeybindsInCategory(category) {
    return root.filteredKeybindHelpEntries().filter(entry => entry.category === category);
  }
  function selectedKeybinds() {
    if (root.keybindHelpSelectedKey.length === 0) return [];
    return root.keybindsForKey(root.keybindHelpSelectedKey);
  }
  function keybindKeyLabel(key) {
    const matches = root.keybindsForKey(key);
    if (matches.length === 0) return "";
    if (matches.length === 1) return matches[0].description;
    return matches.length + " binds";
  }
  function keyWidthUnits(key) {
    if (key === "") return 1;
    if (key === "Space") return 5.4;
    if (key === "Backspace") return 1.7;
    if (key === "Tab" || key === "Caps" || key === "Enter") return 1.45;
    if (key === "Shift") return 1.75;
    if (key === "Mouse Left" || key === "Mouse Right" || key === "Wheel Up" || key === "Wheel Down") return 1.8;
    return 1;
  }
  function isSmallWidget(page) {
    return page === "audio" || page === "media" || page === "weather" || page === "codex" || page === "shutdown";
  }
  function widgetPreferredWidth() {
    if (widgetPage === "screenshot") return 940;
    if (widgetPage === "calendar") return widgetWindow.width;
    if (widgetPage === "clipboard") return 460;
    if (widgetPage === "tools") return 340;
    if (root.isSmallWidget(widgetPage)) return 430;
    return 420;
  }
  function widgetPreferredHeight() {
    if (widgetPage === "screenshot") return 860;
    if (widgetPage === "calendar") return widgetWindow.height;
    if (widgetPage === "clipboard") return 560;
    if (widgetPage === "tools") return 340;
    if (root.isSmallWidget(widgetPage)) return 500;
    return 620;
  }
  function audioNodeLabel(node) {
    return node ? (node.description || node.nickname || node.name || "Unknown device") : "No device";
  }
  function audioSinks() {
    const sinks = Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream);
    if (sinks.length === 0 && Pipewire.defaultAudioSink) return [Pipewire.defaultAudioSink];
    return sinks;
  }
  function audioSources() {
    const sources = Pipewire.nodes.values.filter(node => node.audio && node.isSource && !node.isStream);
    if (sources.length === 0 && Pipewire.defaultAudioSource) return [Pipewire.defaultAudioSource];
    return sources;
  }
  function selectAudioSink(node) {
    if (node) Pipewire.preferredDefaultAudioSink = node;
  }
  function selectAudioSource(node) {
    if (node) Pipewire.preferredDefaultAudioSource = node;
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
    root.closeWidget();
    Qt.callLater(() => root.runTool(command, title, detail));
  }
  function runScreenshotEditedTool(action, title, detail) {
    if (root.screenshotPath.length === 0) return;
    root.runWidgetTool(root.screenshotEditedArgs(action), title, detail);
  }
  function saveEditedScreenshot() {
    root.runScreenshotEditedTool("save-edited", "Screenshot", "Saved edited image");
  }
  function copyEditedScreenshot() {
    root.runScreenshotEditedTool("copy-edited", "Screenshot", "Copied edited image");
  }
  function captureScreenshot(mode, openAfter) {
    if (root.widgetVisible && root.widgetPage === "screenshot") {
      root.closeWidget();
      root.widgetWindowShown = false;
    }
    root.screenshotPath = "";
    root.screenshotAnnotations = [];
    root.screenshotCurrentStroke = null;
    root.pendingScreenshotMode = mode;
    root.pendingScreenshotOpenAfterCapture = openAfter;
    root.screenshotCaptureQueued = true;
    root.toolBusy = true;
    root.toolStatusVisible = false;
    root.toolStatusTitle = "Screenshot";
    root.toolStatusDetail = mode === "edit" ? "Select an area for preview" : "Select an area to save";
    toolStatusTimer.stop();
    if (screenshotAction.running) {
      screenshotAction.running = false;
    } else {
      root.startScreenshotCapture(mode, openAfter);
    }
  }
  function startScreenshotCapture(mode, openAfter) {
    root.screenshotOpenAfterCapture = openAfter;
    root.screenshotCaptureQueued = false;
    screenshotAction.exec(["@screenshotTool@", mode]);
  }
  function screenshotEditedArgs(action) {
    return ["@screenshotTool@", action, root.screenshotPath, JSON.stringify(root.screenshotAnnotations)];
  }
  function pad2(value) {
    const text = String(Math.max(0, Math.min(99, Math.round(value))));
    return text.length < 2 ? "0" + text : text;
  }
  function codexUsageValue(key) {
    if (!root.codexUsage) return null;
    const value = Number(root.codexUsage[key]);
    return Number.isFinite(value) ? value : null;
  }
  function codexUsageRemainingPercent(value) {
    const used = Number(value);
    if (!Number.isFinite(used)) return null;
    const remaining = 100 - used;
    if (!Number.isFinite(remaining)) return null;
    return Math.max(0, Math.min(100, Math.round(remaining)));
  }
  function codexUsageSummaryText() {
    if (root.codexUsageError.length > 0) return "!";
    const codexUsed = root.codexUsageValue("codexPrimaryUsedPercent");
    const sparkAvailable = root.codexUsageValue("sparkPrimaryUsedPercent");
    const sparkUsed = Number.isFinite(sparkAvailable) ? 100 - sparkAvailable : null;
    if (codexUsed === null && sparkUsed === null) return "—";
    if (codexUsed === null) return "— / " + Math.round(sparkUsed) + "%";
    if (sparkUsed === null) return Math.round(codexUsed) + "% / —";
    return Math.round(codexUsed) + "% / " + Math.round(sparkUsed) + "%";
  }
  function codexUsageColor() {
    const primaryUsed = root.codexUsageValue("codexPrimaryUsedPercent");
    const sparkAvailable = root.codexUsageValue("sparkPrimaryUsedPercent");
    const sparkUsed = Number.isFinite(sparkAvailable) ? 100 - sparkAvailable : null;
    const codexRisk = Number.isFinite(primaryUsed) ? primaryUsed : -1;
    const sparkRisk = Number.isFinite(sparkUsed) ? sparkUsed : -1;
    const risk = Math.max(codexRisk, sparkRisk);
    if (risk < 0) return Theme.muted;
    if (risk >= 90) return Theme.danger;
    if (risk >= 75) return Theme.warning;
    return Theme.text;
  }
  function codexUsageResetLabel(expiresAt) {
    const target = Number(expiresAt);
    if (!Number.isFinite(target) || target <= 0) return "—";
    const seconds = Math.floor(target - Date.now() / 1000);
    if (seconds <= 0) return "now";
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.max(1, Math.floor((seconds % 3600) / 60));
    const clockText = Qt.formatDateTime(new Date(target * 1000), "HH:mm");
    if (days > 0) return days + "d " + hours + "h (" + clockText + ")";
    if (hours > 0) return hours + "h " + minutes + "m (" + clockText + ")";
    return minutes + "m (" + clockText + ")";
  }
  function codexUsageTooltipText() {
    if (root.codexUsageError.length > 0)
      return "Codex usage: " + root.codexUsageError;
    if (!root.codexUsage) return "Codex usage unavailable";
    const planType = root.codexUsage.planType || "unknown";
    const codexUsed = root.codexUsageValue("codexPrimaryUsedPercent");
    const sparkAvailable = root.codexUsageValue("sparkPrimaryUsedPercent");
    const sparkUsed = Number.isFinite(sparkAvailable) ? 100 - sparkAvailable : null;
    const codexReset = root.codexUsageResetLabel(root.codexUsageValue("codexPrimaryResetsAt"));
    const sparkReset = root.codexUsageResetLabel(root.codexUsageValue("sparkPrimaryResetsAt"));
    const codexWindow = root.codexUsageWindowLabel(root.codexUsageValue("codexPrimaryWindowMinutes"));
    const sparkWindow = root.codexUsageWindowLabel(root.codexUsageValue("sparkPrimaryWindowMinutes"));
    return "Codex usage (" + planType + ")\n" +
      "Codex: " + (codexUsed === null ? "—" : Math.round(codexUsed) + "% used, reset " + codexReset) + " (" + codexWindow + ")\n" +
      "Spark: " + (sparkUsed === null ? "—" : Math.round(sparkUsed) + "% used, reset " + sparkReset) + " (" + sparkWindow + ")";
  }
  function codexUsageWindowLabel(minutesValue) {
    const minutes = Number(minutesValue);
    if (!Number.isFinite(minutes)) return "—";
    const days = Math.floor(minutes / 1440);
    const hours = Math.floor((minutes % 1440) / 60);
    const rest = Math.round(minutes % 60);
    if (days > 0) return days + "d " + hours + "h";
    if (hours > 0) return hours + "h " + rest + "m";
    return rest + "m";
  }
  function setShutdownDelay(minutes) {
    root.shutdownDelayMinutes = Math.max(1, Math.min(720, Math.round(minutes)));
  }
  function shutdownDelayLabel() {
    const minutes = root.shutdownDelayMinutes;
    if (minutes < 60) return minutes + " min";
    const hours = Math.floor(minutes / 60);
    const rest = minutes % 60;
    return rest === 0 ? hours + " h" : hours + " h " + rest + " min";
  }
  function shutdownRemainingLabel() {
    const seconds = Math.max(0, root.shutdownRemaining);
    const minutes = Math.floor(seconds / 60);
    const rest = seconds % 60;
    return root.pad2(minutes) + ":" + root.pad2(rest);
  }
  function applyShutdownStatus(text) {
    try {
      const payload = JSON.parse(text.trim());
      root.shutdownCustomTarget = payload.custom || "";
      root.shutdownPendingTarget = payload.pending || "";
      root.shutdownRemaining = Number(payload.remaining || 0);
      if (root.shutdownPendingTarget.length > 0)
        root.shutdownStatus = "Pending " + root.shutdownPendingTarget + " · " + root.shutdownRemainingLabel() + " left";
      else if (root.shutdownCustomTarget.length > 0)
        root.shutdownStatus = "Shutdown set " + root.shutdownCustomTarget;
      else
        root.shutdownStatus = "No shutdown timer set";
    } catch (error) {
      root.shutdownStatus = "Could not read shutdown timer";
    }
  }
  function runShutdownTimer(args) {
    if (shutdownTimerAction.running) shutdownTimerAction.running = false;
    shutdownTimerAction.exec(["@shutdownTimerTool@"].concat(args));
  }
  function refreshShutdownStatus() {
    root.runShutdownTimer(["status"]);
  }
  function scheduleShutdown() {
    root.runShutdownTimer(["schedule-in", String(root.shutdownDelayMinutes)]);
  }
  function cancelPendingShutdown() {
    root.runShutdownTimer(["cancel-pending"]);
  }
  function notificationTimeLabel(notification) {
    if (!notification) return "";
    const candidates = [
      notification.receivedAt,
      notification.time,
      notification.timestamp,
      notification.created,
      notification.createdAt,
      notification.sentAt,
      notification.date,
      notification.timestampMs
    ];
    for (let i = 0; i < candidates.length; i++) {
      const value = candidates[i];
      let date = null;
      if (typeof value === "number") {
        date = value > 0 ? new Date(value < 1e12 ? value * 1000 : value) : null;
      } else if (typeof value === "string") {
        const asNumber = Number(value);
        if (Number.isFinite(asNumber))
          date = new Date(asNumber < 1e12 ? asNumber * 1000 : asNumber);
        else if (value.length > 0) {
          const parsed = Date.parse(value);
          date = Number.isFinite(parsed) ? new Date(parsed) : null;
        }
      } else if (value instanceof Date) {
        date = value;
      }
      if (date && Number.isFinite(date.getTime()))
        return Qt.formatDateTime(date, "HH:mm");
    }
    return "";
  }
  function filteredClipboardEntries() {
    const query = root.clipboardFilter.trim().toLowerCase();
    if (query.length === 0) return root.clipboardEntries;
    return root.clipboardEntries.filter(entry =>
      String(entry.preview || "").toLowerCase().includes(query) ||
      String(entry.id || "").toLowerCase().includes(query));
  }
  function runClipboardAction(action, entry) {
    if (clipboardAction.running) clipboardAction.running = false;
    if (action === "wipe") {
      clipboardAction.exec(["@clipboardTool@", "wipe"]);
      root.clipboardStatus = "Clearing history...";
      root.closeWidget();
      return;
    }
    if (!entry || !entry.line) return;
    clipboardAction.exec(["@clipboardTool@", action, entry.line]);
    root.clipboardStatus = action === "copy" ? "Copied" : "Removed";
    if (action === "copy") root.closeWidget();
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
  function screenshotDrawText(context, annotation, canvas, image) {
    if (!annotation || !annotation.text || image.sourceSize.width <= 0 || image.sourceSize.height <= 0)
      return;
    const rect = root.screenshotDisplayRect(canvas, image);
    const x = rect.x + annotation.x / image.sourceSize.width * rect.width;
    const y = rect.y + annotation.y / image.sourceSize.height * rect.height;
    const size = Math.max(8, (annotation.size || root.screenshotTextSize) * rect.width / image.sourceSize.width);
    context.font = "700 " + size + "px \"" + Theme.fontSans + "\"";
    context.textBaseline = "top";
    context.lineJoin = "round";
    context.strokeStyle = "rgba(0, 0, 0, 0.72)";
    context.lineWidth = Math.max(2, size / 9);
    context.fillStyle = annotation.color || root.screenshotInk;
    context.strokeText(annotation.text, x, y);
    context.fillText(annotation.text, x, y);
  }
  function screenshotDrawAnnotation(context, annotation, canvas, image) {
    if (!annotation) return;
    if (annotation.type === "text") root.screenshotDrawText(context, annotation, canvas, image);
    else root.screenshotDrawStroke(context, annotation, canvas, image);
  }
  function addScreenshotText(point) {
    const text = root.screenshotTextDraft.trim();
    if (!point || text.length === 0) return;
    root.screenshotAnnotations = root.screenshotAnnotations.concat([{
      type: "text",
      text,
      x: point.x,
      y: point.y,
      color: root.screenshotInk,
      size: root.screenshotTextSize
    }]);
    screenshotCanvas.requestPaint();
  }
  function dateKey(date) {
    return Qt.formatDateTime(date, "yyyy-MM-dd");
  }
  function calendarDisplayDate() {
    return new Date(clock.date.getFullYear(), clock.date.getMonth() + root.calendarMonthOffset, 1);
  }
  function weatherGlyph() {
    return root.weatherGlyphForCode(root.weatherData ? root.weatherData.weatherCode : NaN);
  }
  function weatherGlyphForCode(code) {
    const value = Number(code);
    if (!Number.isFinite(value)) return "󰖙";
    const codeValue = Math.trunc(value);
    if (codeValue === 0) return "󰖙";
    if ([1, 2, 3].includes(codeValue)) return "󰖐";
    if ([45, 48].includes(codeValue)) return "󰖑";
    if ([51, 53, 55, 56, 57].includes(codeValue)) return "󰖗";
    if ([61, 63, 65, 66, 67, 80, 81, 82].includes(codeValue)) return "󰖖";
    if ([71, 73, 75, 77].includes(codeValue)) return "󰼶";
    if ([95, 96, 99].includes(codeValue)) return "󰖓";
    return "󰖙";
  }
  function weatherIconKindForCode(code) {
    const value = Number(code);
    if (!Number.isFinite(value)) return "cloud";
    const codeValue = Math.trunc(value);
    if (codeValue === 0) return "sun";
    if ([1, 2].includes(codeValue)) return "partly";
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].includes(codeValue)) return "rain";
    if ([71, 73, 75, 77].includes(codeValue)) return "snow";
    if ([95, 96, 99].includes(codeValue)) return "storm";
    return "cloud";
  }
  function weatherIconKind() {
    return root.weatherIconKindForCode(root.weatherData ? root.weatherData.weatherCode : NaN);
  }
  function weatherColorForCode(code) {
    const value = Number(code);
    if (!Number.isFinite(value)) return Theme.accent;
    const codeValue = Math.trunc(value);
    if (codeValue === 0) return "#facc15";
    if ([1, 2].includes(codeValue)) return "#38bdf8";
    if (codeValue === 3) return "#94a3b8";
    if ([45, 48].includes(codeValue)) return "#a78bfa";
    if ([51, 53, 55, 56, 57].includes(codeValue)) return "#22d3ee";
    if ([61, 63, 65, 66, 67, 80, 81, 82].includes(codeValue)) return "#3b82f6";
    if ([71, 73, 75, 77].includes(codeValue)) return "#e0f2fe";
    if ([95, 96, 99].includes(codeValue)) return "#f59e0b";
    return Theme.accent;
  }
  function weatherSurfaceForCode(code) {
    const value = Number(code);
    if (!Number.isFinite(value)) return Theme.surface;
    const codeValue = Math.trunc(value);
    if (codeValue === 0) return "#2f2a12";
    if ([1, 2].includes(codeValue)) return "#102b38";
    if (codeValue === 3) return "#1e293b";
    if ([45, 48].includes(codeValue)) return "#261f3b";
    if ([51, 53, 55, 56, 57].includes(codeValue)) return "#10313a";
    if ([61, 63, 65, 66, 67, 80, 81, 82].includes(codeValue)) return "#14264a";
    if ([71, 73, 75, 77].includes(codeValue)) return "#1f3442";
    if ([95, 96, 99].includes(codeValue)) return "#3a2410";
    return Theme.surface;
  }
  function weatherShortDate(isoDate) {
    if (!isoDate) return "—";
    const parts = isoDate.split("-");
    if (parts.length === 3) return `${parts[2]}.${parts[1]}`;
    return isoDate;
  }
  function weatherHourLabel(isoTime) {
    if (!isoTime || isoTime.length < 16) return "—";
    return isoTime.substring(11, 16);
  }
  function weatherIsToday(isoDate) {
    return isoDate === root.dateKey(clock.date);
  }
  function weatherIsCurrentHour(isoTime) {
    if (!isoTime || isoTime.length < 13) return false;
    return isoTime.substring(0, 13) === Qt.formatDateTime(clock.date, "yyyy-MM-ddTHH");
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
  function calendarDayItems(date, limit) {
    if (!date) return [];
    const items = root.calendarEvents
      .filter(event => event.date === date)
      .map(event => {
        const copy = Object.assign({}, event);
        copy.nowMarker = false;
        copy.sortMinutes = event.startTime && !event.task ? root.calendarMinutesFromClock(event.startTime, 0) : (event.task ? 1500 : -1);
        return copy;
      });
    if (date === root.dateKey(clock.date)) {
      items.push({
        nowMarker: true,
        task: false,
        completed: false,
        title: Qt.formatDateTime(clock.date, "HH:mm"),
        sortMinutes: clock.date.getHours() * 60 + clock.date.getMinutes()
      });
    }
    items.sort((a, b) => a.sortMinutes - b.sortMinutes || Number(Boolean(b.task)) - Number(Boolean(a.task)) || Number(Boolean(a.completed)) - Number(Boolean(b.completed)) || String(a.title || "").localeCompare(String(b.title || "")));
    return limit === undefined ? items : items.slice(0, limit);
  }
  function calendarDayOverflow(date, limit) {
    if (!date) return 0;
    const count = root.calendarEvents.filter(event => event.date === date).length;
    return Math.max(0, count - (limit || 3));
  }
  function calendarEventStartDate(event) {
    if (!event || !event.date || !event.startTime || event.allDay || event.task || event.completed)
      return null;
    const date = new Date(event.date + "T" + event.startTime + ":00");
    return Number.isFinite(date.getTime()) ? date : null;
  }
  function calendarEventMinutesUntil(event) {
    const date = root.calendarEventStartDate(event);
    if (!date) return null;
    return Math.ceil((date.getTime() - clock.date.getTime()) / 60000);
  }
  function calendarUpcomingAlert() {
    const candidates = root.calendarEvents
      .map(event => ({ event: event, minutes: root.calendarEventMinutesUntil(event) }))
      .filter(item => item.minutes !== null && item.minutes >= 0 && item.minutes <= 30)
      .sort((a, b) => a.minutes - b.minutes || String(a.event.title || "").localeCompare(String(b.event.title || "")));
    if (candidates.length === 0) return null;
    const item = candidates[0];
    return {
      title: item.event.title || "Event",
      date: item.event.date,
      startTime: item.event.startTime || "",
      minutes: item.minutes
    };
  }
  function todayActiveTasks(limit) {
    const today = root.dateKey(clock.date);
    const tasks = root.calendarEvents
      .filter(event => Boolean(event.task) && !Boolean(event.completed) && event.date === today)
      .slice()
      .sort((a, b) => String(a.title || "").localeCompare(String(b.title || "")));
    return limit === undefined ? tasks : tasks.slice(0, limit);
  }
  function calendarAlertTimeLabel(alert) {
    if (!alert) return "";
    if (alert.minutes <= 0) return "now";
    return alert.minutes + "m";
  }
  function upcomingEvents(limit, fromDate) {
    const firstDate = fromDate || dateKey(clock.date);
    return root.calendarEvents
      .filter(event => event.date >= firstDate)
      .slice()
      .sort((a, b) => a.date.localeCompare(b.date) || a.title.localeCompare(b.title))
      .slice(0, limit || 10);
  }
	  function selectedDayEvents() {
	    return root.calendarEvents
	      .filter(event => event.date === root.calendarSelectedDate)
	      .slice()
	      .sort((a, b) => Number(Boolean(b.task)) - Number(Boolean(a.task)) || Number(Boolean(a.completed)) - Number(Boolean(b.completed)) || (a.startTime || "").localeCompare(b.startTime || "") || a.title.localeCompare(b.title));
	  }
  function calendarClock(minutes) {
    const normalized = ((minutes % 1440) + 1440) % 1440;
    const hour = Math.floor(normalized / 60);
    const minute = normalized % 60;
    return String(hour).padStart(2, "0") + ":" + String(minute).padStart(2, "0");
  }
  function calendarTimeOptions() {
    const options = [];
    for (let minutes = 0; minutes < 1440; minutes += 15)
      options.push(root.calendarClock(minutes));
    return options;
  }
  function setCalendarStartClock(value) {
    root.calendarEventStartMinutes = root.calendarMinutesFromClock(value, root.calendarEventStartMinutes);
  }
  function setCalendarEndClock(value) {
    root.calendarEventDurationMinutes = root.calendarDurationFromClocks(root.calendarClock(root.calendarEventStartMinutes), value);
  }
  function adjustCalendarStart(delta) {
    root.calendarEventStartMinutes = ((root.calendarEventStartMinutes + delta) % 1440 + 1440) % 1440;
  }
  function adjustCalendarDuration(delta) {
    root.calendarEventDurationMinutes = Math.max(15, Math.min(480, root.calendarEventDurationMinutes + delta));
  }
  function adjustCalendarTime(action, delta) {
    if (action === "start") root.adjustCalendarStart(delta);
    else if (action === "duration") root.adjustCalendarDuration(delta);
  }
  function startCalendarTimeRepeat(action, delta) {
    root.calendarRepeatAction = action;
    root.calendarRepeatDelta = delta;
    root.adjustCalendarTime(action, delta);
    calendarTimeRepeatTimer.restart();
  }
  function stopCalendarTimeRepeat() {
    calendarTimeRepeatTimer.stop();
    root.calendarRepeatAction = "";
    root.calendarRepeatDelta = 0;
  }
  function calendarEndClock() {
    return root.calendarClock(root.calendarEventStartMinutes + root.calendarEventDurationMinutes);
  }
  function calendarMinutesFromClock(value, fallback) {
    if (!value || value.length < 5) return fallback;
    const hour = Number(value.substring(0, 2));
    const minute = Number(value.substring(3, 5));
    if (!Number.isFinite(hour) || !Number.isFinite(minute)) return fallback;
    return Math.max(0, Math.min(1439, hour * 60 + minute));
  }
  function calendarDurationFromClocks(start, end) {
    const startMinutes = root.calendarMinutesFromClock(start, root.calendarEventStartMinutes);
    const endMinutes = root.calendarMinutesFromClock(end, startMinutes + root.calendarEventDurationMinutes);
    let duration = endMinutes - startMinutes;
    if (duration <= 0) duration += 1440;
    return Math.max(15, Math.min(480, duration));
  }
  function resetCalendarEditor() {
    root.calendarTitleDraft = "";
    root.calendarStartDraft = "";
    root.calendarEndDraft = "";
    root.calendarEditingHref = "";
    root.calendarEditingKind = "";
    root.calendarAllDay = false;
  }
  function editCalendarItem(item) {
    if (!item || !item.href || item.note || item.source === "Obsidian")
      return;
    root.calendarEditingHref = item.href;
    root.calendarEditingKind = item.task ? "task" : "event";
    root.calendarEntryMode = root.calendarEditingKind;
    root.calendarTitleDraft = item.title || "";
    root.calendarAllDay = !item.task && Boolean(item.allDay);
    if (!item.task) {
      root.calendarEventStartMinutes = root.calendarMinutesFromClock(item.startTime, root.calendarEventStartMinutes);
      root.calendarEventDurationMinutes = root.calendarDurationFromClocks(item.startTime, item.endTime);
    }
  }
  function calendarSaveLabel() {
    return root.calendarEditingHref.length > 0 ? "Save" : "+";
  }
  function completeCalendarTask(href) {
    if (!href || calendarTaskAction.running)
      return;
    root.runCalendarAction(["@calendarTask@", "complete-task", href]);
  }
  function deleteCalendarItem(href) {
    if (!href || calendarTaskAction.running)
      return;
    root.runCalendarAction(["@calendarTask@", "delete-item", href]);
  }
  function openCalendarNote(noteId) {
    if (!noteId || calendarTaskAction.running)
      return;
    root.runCalendarAction(["@calendarTask@", "open-note", String(noteId)]);
  }
  function undoCalendarChange() {
    if (!root.calendarCanUndo || calendarTaskAction.running)
      return;
    root.runCalendarAction(["@calendarTask@", "undo"]);
  }
  function runCalendarAction(args) {
    calendarTaskAction.actionName = args.length > 1 ? args[1] : "";
    calendarTaskAction.exec(args);
  }
  function addCalendarItem() {
    const title = root.calendarTitleDraft.trim();
    if (title.length === 0 || calendarTaskAction.running)
      return;
    if (root.calendarEntryMode === "event") {
      const action = root.calendarEditingHref.length > 0 ? "edit-event" : "add-event";
      const args = ["@calendarTask@", action];
      if (root.calendarEditingHref.length > 0) args.push(root.calendarEditingHref);
      args.push(root.calendarSelectedDate);
      args.push(title);
      if (!root.calendarAllDay) {
        args.push(root.calendarClock(root.calendarEventStartMinutes));
        args.push(root.calendarEndClock());
      }
      root.runCalendarAction(args);
    } else if (root.calendarEditingHref.length > 0) {
      root.runCalendarAction(["@calendarTask@", "edit-task", root.calendarEditingHref, root.calendarSelectedDate, title]);
    } else {
      root.runCalendarAction(["@calendarTask@", "add-task", root.calendarSelectedDate, title]);
    }
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
      notification.receivedAt = Date.now();
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
            color: Theme.text; font.family: Theme.fontSans; font.pixelSize: 68
          }
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: 16
          }
          Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 52
            radius: 12; color: Theme.surface; border.color: password.activeFocus ? Theme.accent : Theme.border
            TextInput {
              id: password
              anchors.fill: parent; anchors.margins: 14
              focus: true; echoMode: TextInput.Password
              color: Theme.text; font.family: Theme.font; font.pixelSize: 17
              cursorDelegate: root.themedCursor
              selectionColor: Theme.accent
              selectedTextColor: Theme.background
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
            font.family: Theme.fontSans; font.pixelSize: 12
          }
        }
      }
    }
  }
  GlobalShortcut {
    name: "powerMenu"
    description: "Toggle power menu"
    onPressed: {
      root.closeWidget();
      root.keybindHelpVisible = false;
      root.launcherVisible = false;
      root.notificationHistoryVisible = false;
      root.powerVisible = !root.powerVisible;
    }
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

      MouseArea {
        anchors.fill: parent
        onClicked: root.closeTransientPanels()
      }

      Item {
        anchors.fill: parent
        anchors.margins: 3

        ColumnLayout {
          id: workspaceStack
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: 7

        Repeater {
          model: root.workspaceEntries
          Rectangle {
            id: workspaceCell
            required property var modelData
            readonly property var clients: root.workspaceClientList(modelData.id, 5)
            readonly property bool dragTarget: root.workspaceDragTarget === modelData.id
            readonly property bool active: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
            Layout.fillWidth: true
            implicitHeight: root.workspaceCellHeight(modelData.id)
            radius: 18
            color: dragTarget ? Theme.accentSoft : (active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, clients.length > 0 ? 0.08 : 0.02))
            border.color: dragTarget || active ? Theme.accent : "transparent"
            border.width: 1
            scale: dragTarget ? 1.06 : 1
            Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            MouseArea {
              id: workspaceCellMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.openWorkspace(workspaceCell.modelData.id);
              }
            }

            Column {
              visible: workspaceCell.clients.length > 0
              anchors.centerIn: parent
              spacing: 6
              Repeater {
                model: workspaceCell.clients
                Item {
                  id: clientBubble
                  required property var modelData
                  width: 30
                  height: 30
                  z: root.workspaceDragClient && root.workspaceDragClient.address === modelData.address ? 10 : 1
                  scale: clientMouse.pressed ? 1.16 : (clientMouse.containsMouse ? 1.08 : 1)
                  opacity: root.workspaceDragClient && root.workspaceDragClient.address === modelData.address ? 0.82 : 1
                  Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                  Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                  Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    color: clientMouse.containsMouse || (root.workspaceDragClient && root.workspaceDragClient.address === parent.modelData.address) ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08) : "transparent"
                    border.color: clientMouse.containsMouse || (root.workspaceDragClient && root.workspaceDragClient.address === parent.modelData.address) ? Theme.border : "transparent"
                    border.width: 1
                  }
                  IconImage {
                    anchors.centerIn: parent
                    implicitSize: root.appIconSizeForClient(parent.modelData, 24)
                    source: root.appIconSourceForClient(parent.modelData)
                  }
                  MouseArea {
                    id: clientMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: clientBubble
                    drag.axis: Drag.YAxis
                    drag.threshold: 4
                    onClicked: mouse => {
                      root.openWorkspace(workspaceCell.modelData.id);
                    }
                    onPressed: {
                      root.workspaceDragClient = parent.modelData;
                      root.workspaceDragTarget = workspaceCell.modelData.id;
                    }
                    onPositionChanged: mouse => {
                      if (!pressed) return;
                      const point = mapToItem(workspaceStack, mouse.x, mouse.y);
                      root.workspaceDragTarget = root.workspaceIdAtY(point.y);
                    }
                    onReleased: mouse => {
                      const point = mapToItem(workspaceStack, mouse.x, mouse.y);
                      const target = root.workspaceIdAtY(point.y);
                      clientBubble.x = 0;
                      clientBubble.y = 0;
                      if (target !== 0)
                        root.moveWorkspaceClient(parent.modelData, target);
                      else {
                        root.clearWorkspaceInteraction();
                      }
                    }
                    onCanceled: {
                      clientBubble.x = 0;
                      clientBubble.y = 0;
                      root.clearWorkspaceInteraction();
                    }
                  }
                }
              }
              Rectangle {
                visible: (root.workspaceClientsById[String(workspaceCell.modelData.id)] || []).length > workspaceCell.clients.length
                width: 28
                height: 20
                radius: 10
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                border.color: Theme.border
                border.width: 1
                Text {
                  anchors.centerIn: parent
                  text: "+" + ((root.workspaceClientsById[String(workspaceCell.modelData.id)] || []).length - workspaceCell.clients.length)
                  color: Theme.accent
                  font.family: Theme.fontSans
                  font.pixelSize: 10
                  font.bold: true
                }
              }
            }
            Rectangle {
              visible: workspaceCell.clients.length === 0
              anchors.centerIn: parent
              width: 7
              height: 7
              radius: 4
              color: workspaceCell.active ? Theme.accent : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.28)
            }
          }
        }
        }

        ColumnLayout {
          id: calendarBarStack
          anchors.centerIn: parent
          width: 38
          spacing: 7

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 38
          Layout.preferredHeight: 118
          readonly property var alert: root.calendarUpcomingAlert()
          visible: true
          opacity: alert !== null ? 1 : 0
          radius: 8
          color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
          border.color: "transparent"
          border.width: 0
          clip: true

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2
            Text {
              Layout.fillWidth: true
              text: "󰃭"
              color: Theme.accent
              font.family: Theme.fontIcon
              font.pixelSize: 13
              horizontalAlignment: Text.AlignHCenter
            }
            Text {
              Layout.fillWidth: true
              text: parent.parent.alert ? (parent.parent.alert.startTime || root.calendarAlertTimeLabel(parent.parent.alert)) : ""
              color: Theme.text
              font.family: Theme.fontSans
              font.pixelSize: 10
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              text: parent.parent.alert ? root.calendarAlertTimeLabel(parent.parent.alert) : ""
              color: Theme.accent
              font.family: Theme.fontSans
              font.pixelSize: 9
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              Layout.fillHeight: true
              text: parent.parent.alert ? parent.parent.alert.title : ""
              color: Theme.text
              font.family: Theme.fontSans
              font.pixelSize: 8
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.Wrap
              maximumLineCount: 4
              elide: Text.ElideRight
            }
          }
          MouseArea {
            anchors.fill: parent
            enabled: parent.alert !== null
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (parent.alert && parent.alert.date)
                root.calendarSelectedDate = parent.alert.date;
              root.toggleWidget("calendar");
            }
          }
        }

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 38
          Layout.preferredHeight: Math.min(98, 28 + root.todayActiveTasks(3).length * 22)
          readonly property var tasks: root.todayActiveTasks(3)
          visible: tasks.length > 0
          radius: 8
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
          border.color: "transparent"
          border.width: 0
          clip: true

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2
            Text {
              Layout.fillWidth: true
              text: "󰄬 " + parent.parent.tasks.length
              color: Theme.accent
              font.family: Theme.fontIcon
              font.pixelSize: 12
              horizontalAlignment: Text.AlignHCenter
            }
            Repeater {
              model: parent.parent.tasks
              Text {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.title || "Task"
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: 8
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 2
                wrapMode: Text.Wrap
                elide: Text.ElideRight
              }
            }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.calendarSelectedDate = root.dateKey(clock.date);
              root.toggleWidget("calendar");
            }
          }
        }

        }

        ColumnLayout {
          id: barActionStack
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: 7

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 34
          Layout.preferredHeight: 34
          id: trayToggle
          radius: 8
          color: root.trayExpanded ? Theme.accentSoft : "transparent"
          border.color: root.trayExpanded ? Theme.accent : "transparent"
          border.width: 1
          Text {
            anchors.centerIn: parent
            text: root.trayExpanded ? "󰅀" : "󰅂"
            color: root.trayExpanded ? Theme.accent : Theme.text
            font.family: Theme.fontIcon
            font.pixelSize: 16
          }
          MouseArea {
            id: trayToggleMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.closeTransientPanels();
              root.trayExpanded = !root.trayExpanded;
            }
          }
        }

        ColumnLayout {
          visible: root.trayExpanded
          Layout.alignment: Qt.AlignHCenter
          spacing: 6

          Repeater {
            model: SystemTray.items
            Item {
              required property var modelData
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: 34
              implicitHeight: 34
              IconImage {
                anchors.centerIn: parent
                implicitSize: 20
                source: parent.modelData.icon
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                  root.closeTransientPanels();
                  if (mouse.button === Qt.RightButton && parent.modelData.hasMenu)
                    parent.modelData.display(bar, 0, mapToItem(bar.contentItem, 0, 0).y);
                  else if (mouse.button === Qt.MiddleButton) parent.modelData.secondaryActivate();
                  else parent.modelData.activate();
                }
              }
            }
          }
        }

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 34
          Layout.preferredHeight: 34
          id: kanataIcon
          radius: 8
          color: {
            if (!root.kanataKnown) return Theme.surface;
            return root.kanataActive ? Theme.accent : "transparent";
          }
          border.color: !root.kanataKnown ? Theme.danger : (root.kanataActive ? Theme.accent : Theme.border)
          border.width: 1
          Text {
            anchors.centerIn: parent
            text: ""
            color: root.kanataActive ? Theme.background : (root.kanataKnown ? Theme.text : Theme.danger)
            font.family: Theme.fontIcon
            font.pixelSize: 18
            font.bold: true
          }
          MouseArea {
            anchors.fill: parent
            id: kanataMouse
            cursorShape: Qt.PointingHandCursor
            propagateComposedEvents: true
            onClicked: {
              if (kanataToggleAction.running) return;
              kanataToggleAction.running = true;
            }
          }
        }

        Item {
          Layout.alignment: Qt.AlignHCenter
          id: mediaButton
          Layout.preferredWidth: 34
          Layout.preferredHeight: 34
          implicitWidth: 34
          implicitHeight: 34
          ToolTip.visible: false
          Rectangle {
            anchors.fill: parent
            radius: 8
            color: root.barWidgetBackground("media")
            border.color: root.barWidgetBorder("media")
            border.width: 1
          }
          Text { anchors.centerIn: parent; text: ""; color: root.barWidgetText("media", root.mediaPlayer ? Theme.text : Theme.muted); font.family: Theme.fontIcon; font.pixelSize: 17 }
          MouseArea {
            id: mediaMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.showHoverWidget("media")
            onExited: root.leaveHoverWidgetButton("media")
            onClicked: root.showHoverWidget("media")
          }
        }

        Item {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 34
          Layout.preferredHeight: 34
          implicitWidth: 34
          implicitHeight: 34
          id: audioButton
          Rectangle {
            anchors.fill: parent
            radius: 8
            color: root.barWidgetBackground("audio")
            border.color: root.barWidgetBorder("audio")
            border.width: 1
          }
          Text {
            id: audioGlyph
            anchors.centerIn: parent
            text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
              ? (Pipewire.defaultAudioSink.audio.muted ? "󰝟" : "") : ""
            color: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted
              ? Theme.danger
              : root.barWidgetText("audio", Theme.text)
            font.family: Theme.fontIcon
            font.pixelSize: 16
          }
          MouseArea {
            id: audioMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.showHoverWidget("audio")
            onExited: root.leaveHoverWidgetButton("audio")
            onClicked: root.showHoverWidget("audio")
            onWheel: wheel => {
              if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio)
                Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1.5, Pipewire.defaultAudioSink.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
            }
          }
        }

        Item {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 34
          Layout.preferredHeight: 34
          implicitWidth: 34
          implicitHeight: 34
          id: weatherButton
          clip: true
          Rectangle {
            anchors.fill: parent
            radius: 8
            color: root.barWidgetBackground("weather")
            border.color: root.barWidgetBorder("weather")
            border.width: 1
          }
          Column {
            anchors.centerIn: parent
            width: 30
            height: 28
            spacing: 0

            Canvas {
              id: barWeatherGlyph
              anchors.horizontalCenter: parent.horizontalCenter
              width: 18
              height: 15
              readonly property color iconColor: root.barWidgetText("weather", Theme.text)
              readonly property string iconKind: root.weatherIconKind()
              onIconColorChanged: requestPaint()
              onIconKindChanged: requestPaint()
              onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = iconColor;
                ctx.fillStyle = iconColor;
                ctx.lineWidth = 1.35;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                const kind = iconKind;
                if (kind === "sun" || kind === "partly") {
                  ctx.beginPath();
                  ctx.arc(kind === "partly" ? 6 : 9, kind === "partly" ? 5 : 6, kind === "partly" ? 2.8 : 3.4, 0, Math.PI * 2);
                  ctx.stroke();
                  for (let i = 0; i < 8; i++) {
                    const angle = (Math.PI * 2 * i) / 8;
                    const cx = kind === "partly" ? 6 : 9;
                    const cy = kind === "partly" ? 5 : 6;
                    const inner = kind === "partly" ? 4.2 : 5;
                    const outer = kind === "partly" ? 5.6 : 6.5;
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(angle) * inner, cy + Math.sin(angle) * inner);
                    ctx.lineTo(cx + Math.cos(angle) * outer, cy + Math.sin(angle) * outer);
                    ctx.stroke();
                  }
                }
                if (kind !== "sun") {
                  ctx.beginPath();
                  ctx.moveTo(4.2, 11.8);
                  ctx.lineTo(13.4, 11.8);
                  ctx.bezierCurveTo(15.4, 11.8, 16.6, 10.5, 16.6, 8.9);
                  ctx.bezierCurveTo(16.6, 7.2, 15.2, 5.9, 13.3, 6.1);
                  ctx.bezierCurveTo(12.4, 3.7, 10.3, 2.5, 8.1, 2.9);
                  ctx.bezierCurveTo(6.1, 3.2, 4.8, 4.5, 4.2, 6.4);
                  ctx.bezierCurveTo(2.4, 6.6, 1.3, 7.8, 1.3, 9.3);
                  ctx.bezierCurveTo(1.3, 10.8, 2.5, 11.8, 4.2, 11.8);
                  ctx.stroke();
                  if (kind === "rain" || kind === "storm") {
                    for (const x of [5.5, 9, 12.5]) {
                      ctx.beginPath();
                      ctx.moveTo(x, 13.2);
                      ctx.lineTo(x - 0.9, 14.4);
                      ctx.stroke();
                    }
                  } else if (kind === "snow") {
                    for (const x of [6.2, 11.8]) {
                      ctx.beginPath();
                      ctx.moveTo(x - 0.9, 13.7);
                      ctx.lineTo(x + 0.9, 13.7);
                      ctx.moveTo(x, 12.8);
                      ctx.lineTo(x, 14.6);
                      ctx.stroke();
                    }
                  }
                }
              }
            }
            Text {
              width: parent.width
              height: 13
              text: root.weatherData && root.weatherData.temperature !== null && root.weatherData.temperature !== undefined ? Math.round(root.weatherData.temperature) + "°" : "—"
              color: root.barWidgetText("weather", Theme.text)
              font.family: Theme.fontSans
              font.pixelSize: 10
              font.bold: true
              lineHeightMode: Text.FixedHeight
              lineHeight: 13
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              minimumPixelSize: 9
              fontSizeMode: Text.Fit
            }
          }
          MouseArea {
            id: weatherMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.showHoverWidget("weather")
            onExited: root.leaveHoverWidgetButton("weather")
            onClicked: root.showHoverWidget("weather")
          }
        }

        Item {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: 34
          Layout.preferredHeight: 34
          implicitWidth: 34
          implicitHeight: 34
          Rectangle {
            anchors.fill: parent
            radius: 8
            color: root.barWidgetBackground("codex")
            border.color: root.barWidgetBorder("codex")
            border.width: 1
          }
          IconImage {
            anchors.centerIn: parent
            implicitSize: 22
            source: Qt.resolvedUrl("assets/codex.svg")
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.showHoverWidget("codex")
            onExited: root.leaveHoverWidgetButton("codex")
            onClicked: root.showHoverWidget("codex")
          }
        }

        Item {
          Layout.alignment: Qt.AlignHCenter
          id: shutdownButton
          Layout.preferredWidth: 34
          Layout.preferredHeight: 34
          implicitWidth: 34
          implicitHeight: 34
          Rectangle {
            anchors.fill: parent
            radius: 8
            color: root.barWidgetBackground("shutdown")
            border.color: root.barWidgetBorder("shutdown")
            border.width: 1
          }
          Text {
            anchors.centerIn: parent
            text: "󰐥"
            color: root.barWidgetText("shutdown", Theme.text)
            font.family: Theme.fontIcon
            font.pixelSize: 17
          }
          MouseArea {
            id: shutdownMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.showHoverWidget("shutdown")
            onExited: root.leaveHoverWidgetButton("shutdown")
            onClicked: root.showHoverWidget("shutdown")
          }
        }

        Item {
          Layout.alignment: Qt.AlignHCenter
          id: clockButton
          Layout.preferredWidth: 34
          Layout.preferredHeight: 34
          implicitWidth: 34
          implicitHeight: 34
          Rectangle {
            anchors.fill: parent
            radius: 8
            color: root.barWidgetBackground("calendar")
            border.color: root.barWidgetBorder("calendar")
            border.width: 1
          }
          Text {
            anchors.fill: parent
            text: Qt.formatDateTime(clock.date, "HH\nmm")
            color: root.barWidgetText("calendar", Theme.text)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            lineHeight: 0.82
            font.family: Theme.fontSans
            font.pixelSize: 12
            font.bold: true
          }
          MouseArea {
            id: clockMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleWidget("calendar")
          }
        }
      }
    }
  }
  }

  PanelWindow {
    id: widgetWindow
    visible: root.widgetWindowShown
    focusable: true
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    margins.right: 44
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      enabled: root.widgetVisible
      onClicked: mouse => {
        const point = mapToItem(widgetPanel, mouse.x, mouse.y);
        if (point.x < 0 || point.y < 0 || point.x > widgetPanel.width || point.y > widgetPanel.height)
          root.closeWidget();
      }
    }

    Rectangle {
      id: widgetPanel
      width: Math.min(root.widgetPreferredWidth(), root.widgetPage === "calendar" ? parent.width : parent.width - 20)
      height: Math.min(root.widgetPreferredHeight(), root.widgetPage === "calendar" ? parent.height : parent.height - 36)
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: root.widgetPage === "calendar" ? 0 : 10
      anchors.bottomMargin: root.widgetPage === "calendar" ? 0 : 18
      radius: root.widgetPage === "calendar" ? 0 : Theme.radiusLg
      color: root.translucentPanel
      border.color: root.widgetPage === "calendar" ? "transparent" : Theme.border
      border.width: root.widgetPage === "calendar" ? 0 : 1
      clip: true
      focus: root.widgetVisible
      opacity: root.widgetVisible ? 1 : 0
      scale: root.widgetVisible ? 1 : 0.96
      transformOrigin: Item.BottomRight
      transform: Translate {
        y: root.widgetVisible ? 0 : 14
        Behavior on y { NumberAnimation { duration: root.widgetMotionMs; easing.type: Easing.OutCubic } }
      }
      HoverHandler {
        onHoveredChanged: {
          root.hoverWidgetPanelHovered = hovered;
          if (hovered)
            hoverWidgetCloseTimer.stop();
          else
            root.scheduleHoverWidgetClose(root.widgetPage);
        }
      }
      Behavior on opacity { NumberAnimation { duration: root.widgetMotionMs; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: root.widgetMotionMs; easing.type: Easing.OutCubic } }
      Behavior on width { NumberAnimation { duration: root.widgetMotionMs; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: root.widgetMotionMs; easing.type: Easing.OutCubic } }
      ColumnLayout {
        anchors.fill: parent; anchors.margins: root.widgetPage === "calendar" ? 28 : Theme.padLg; spacing: Theme.gapMd
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: ({audio: "Audio", media: "Spotify", weather: "Weather", clipboard: "Clipboard", calendar: "Calendar", tools: "Tools", shutdown: "Shutdown", screenshot: "Screenshot", codex: "Codex usage"})[root.widgetPage]
            color: Theme.text; font.family: Theme.fontSans; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true
          }
          Text { text: "×"; color: Theme.muted; font.pixelSize: 22; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closeWidget() } }
        }

        ColumnLayout {
          visible: root.widgetPage === "audio"; Layout.fillWidth: true; spacing: 14
          Text { text: "Output device"; color: Theme.muted; font.family: Theme.fontSans; font.bold: true }
          Rectangle {
            id: outputPicker
            Layout.fillWidth: true
            implicitHeight: 44
            radius: Theme.radiusSm
            color: outputMenu.opened ? Theme.surfaceAlt : Theme.surface
            border.color: outputMenu.opened ? Theme.accent : Theme.border
            border.width: 1
            opacity: Pipewire.defaultAudioSink ? 1 : 0.55
            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 9
              Text { text: ""; color: outputMenu.opened ? Theme.accent : Theme.muted; font.family: Theme.font; font.pixelSize: 17; Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter }
              Text { text: root.audioNodeLabel(Pipewire.defaultAudioSink); color: Theme.text; font.family: Theme.font; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
              Text { text: outputMenu.opened ? "⌃" : "⌄"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 16; Layout.preferredWidth: 18; horizontalAlignment: Text.AlignHCenter }
            }
            MouseArea {
              anchors.fill: parent
              enabled: Pipewire.defaultAudioSink || root.audioSinks().length > 0
              cursorShape: Qt.PointingHandCursor
              onClicked: outputMenu.opened ? outputMenu.close() : outputMenu.open()
            }
            Menu {
              id: outputMenu
              y: outputPicker.height + 4
              width: outputPicker.width
              onOpened: root.setHoverWidgetMenuOpen(true)
              onClosed: root.setHoverWidgetMenuOpen(microphoneMenu.opened)
              background: Rectangle {
                color: Theme.background
                border.color: Theme.border
                border.width: 1
                radius: 8
              }
              Repeater {
                model: ScriptModel { values: root.audioSinks() }
                MenuItem {
                  id: outputMenuItem
                  required property var modelData
                  text: root.audioNodeLabel(modelData)
                  checkable: true
                  checked: modelData === Pipewire.defaultAudioSink
                  onTriggered: root.selectAudioSink(modelData)
                  implicitHeight: 38
                  leftPadding: 12
                  rightPadding: 12
                  topPadding: 6
                  bottomPadding: 6

                  indicator: Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: outputMenuItem.checked ? "✓" : ""
                    color: outputMenuItem.highlighted ? Theme.background : Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 13
                  }

                  contentItem: Text {
                    leftPadding: outputMenuItem.checkable ? 24 : 0
                    rightPadding: 8
                    text: outputMenuItem.text
                    color: outputMenuItem.highlighted || outputMenuItem.checked ? Theme.background : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                  }

                  background: Rectangle {
                    radius: 7
                    color: outputMenuItem.highlighted || outputMenuItem.checked ? Theme.accent : "transparent"
                  }
                }
              }
            }
          }
          RowLayout {
            Layout.fillWidth: true; spacing: 10
            Text {
              text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted ? "󰝟" : ""
              color: Theme.accent; font.family: Theme.fontIcon; font.pixelSize: 22
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted }
            }
            Slider {
              Layout.fillWidth: true; from: 0; to: 1.5
              value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
              onMoved: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.volume = value
            }
            Text { text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "0%"; color: Theme.text; font.family: Theme.font }
          }
          Text { text: "Microphone input"; color: Theme.muted; font.family: Theme.fontSans; font.bold: true; Layout.topMargin: 4 }
          Rectangle {
            id: microphonePicker
            Layout.fillWidth: true
            implicitHeight: 44
            radius: Theme.radiusSm
            color: microphoneMenu.opened ? Theme.surfaceAlt : Theme.surface
            border.color: microphoneMenu.opened ? Theme.accent : Theme.border
            border.width: 1
            opacity: Pipewire.defaultAudioSource ? 1 : 0.55
            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 9
              Text { text: "󰍬"; color: microphoneMenu.opened ? Theme.accent : Theme.muted; font.family: Theme.font; font.pixelSize: 17; Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter }
              Text { text: root.audioNodeLabel(Pipewire.defaultAudioSource); color: Theme.text; font.family: Theme.font; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
              Text { text: microphoneMenu.opened ? "⌃" : "⌄"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 16; Layout.preferredWidth: 18; horizontalAlignment: Text.AlignHCenter }
            }
            MouseArea {
              anchors.fill: parent
              enabled: Pipewire.defaultAudioSource || root.audioSources().length > 0
              cursorShape: Qt.PointingHandCursor
              onClicked: microphoneMenu.opened ? microphoneMenu.close() : microphoneMenu.open()
            }
            Menu {
              id: microphoneMenu
              y: microphonePicker.height + 4
              width: microphonePicker.width
              onOpened: root.setHoverWidgetMenuOpen(true)
              onClosed: root.setHoverWidgetMenuOpen(outputMenu.opened)
              background: Rectangle {
                color: Theme.background
                border.color: Theme.border
                border.width: 1
                radius: 8
              }
              Repeater {
                model: ScriptModel { values: root.audioSources() }
                MenuItem {
                  id: microphoneMenuItem
                  required property var modelData
                  text: root.audioNodeLabel(modelData)
                  checkable: true
                  checked: modelData === Pipewire.defaultAudioSource
                  onTriggered: root.selectAudioSource(modelData)
                  implicitHeight: 38
                  leftPadding: 12
                  rightPadding: 12
                  topPadding: 6
                  bottomPadding: 6

                  indicator: Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: microphoneMenuItem.checked ? "✓" : ""
                    color: microphoneMenuItem.highlighted ? Theme.background : Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 13
                  }

                  contentItem: Text {
                    leftPadding: microphoneMenuItem.checkable ? 24 : 0
                    rightPadding: 8
                    text: microphoneMenuItem.text
                    color: microphoneMenuItem.highlighted || microphoneMenuItem.checked ? Theme.background : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                  }

                  background: Rectangle {
                    radius: 7
                    color: microphoneMenuItem.highlighted || microphoneMenuItem.checked ? Theme.accent : "transparent"
                  }
                }
              }
            }
          }
          RowLayout {
            Layout.fillWidth: true; spacing: 10
            Text {
              text: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio && Pipewire.defaultAudioSource.audio.muted ? "󰍭" : "󰍬"
              color: Theme.accent; font.family: Theme.fontIcon; font.pixelSize: 22
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted }
            }
            Slider {
              Layout.fillWidth: true; from: 0; to: 1.5
              value: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.volume : 0
              onMoved: if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.volume = value
            }
            Text { text: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Math.round(Pipewire.defaultAudioSource.audio.volume * 100) + "%" : "0%"; color: Theme.text; font.family: Theme.font }
          }
        }

        CodexUsageWindow {
          visible: root.widgetPage === "codex"
          shell: root
          Layout.fillWidth: true
          Layout.fillHeight: true
        }

        ColumnLayout {
          visible: root.widgetPage === "media"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
          Image { visible: root.mediaPlayer !== null; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 220; Layout.preferredHeight: 220; fillMode: Image.PreserveAspectCrop; source: root.mediaPlayer ? root.mediaPlayer.trackArtUrl : "" }
          Text { visible: root.mediaPlayer === null; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 70; text: ""; color: Theme.accent; font.family: Theme.font; font.pixelSize: 82 }
          Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.mediaPlayer ? (root.mediaPlayer.trackTitle || "Unknown title") : "Spotify is not running"; color: Theme.text; font.family: Theme.fontSans; font.bold: true; font.pixelSize: 17; wrapMode: Text.Wrap }
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
            radius: Theme.radiusSm
            color: Theme.surface
            Text { anchors.centerIn: parent; text: "  Open Spotify"; color: Theme.accent; font.family: Theme.font }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["spotify"]) }
          }
        }

        ColumnLayout {
          visible: root.widgetPage === "weather"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 10
          clip: true

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 118
            radius: 12
            color: Theme.surfaceAlt
            border.color: Theme.border
            border.width: 1
            clip: true
            RowLayout {
              anchors.fill: parent
              anchors.margins: 14
              spacing: 14
              Text {
                text: root.weatherData ? root.weatherGlyph() : "󰖙"
                color: root.weatherData ? Theme.accent : Theme.muted
                font.family: Theme.fontIcon
                font.pixelSize: 52
                Layout.preferredWidth: 58
                horizontalAlignment: Text.AlignHCenter
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                  text: root.weatherData && root.weatherData.temperature !== null && root.weatherData.temperature !== undefined ? Math.round(root.weatherData.temperature) + "°" : (weatherQuery.running ? "Loading" : "No data")
                  color: Theme.text
                  font.family: Theme.fontSans
                  font.pixelSize: 36
                  font.bold: true
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
                Text {
                  text: root.weatherData ? root.weatherData.description : (root.weatherError || "Warsaw forecast")
                  color: root.weatherError ? Theme.danger : root.secondaryText
                  font.family: Theme.fontSans
                  font.pixelSize: 13
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
                Text {
                  text: root.weatherData && root.weatherLastUpdated ? "Updated " + root.weatherLastUpdated : "Open-Meteo"
                  color: root.secondaryText
                  font.family: Theme.fontSans
                  font.pixelSize: 11
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
              Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 8
                color: Theme.surface
                Text {
                  anchors.centerIn: parent
                  text: "󰑐"
                  color: Theme.text
                  font.family: Theme.fontIcon
                  font.pixelSize: 15
                }
                RotationAnimation on rotation {
                  running: weatherQuery.running
                  loops: Animation.Infinite
                  from: 0
                  to: 360
                  duration: 900
                }
                MouseArea {
                  id: refreshMouse
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (!weatherQuery.running) weatherQuery.running = true
                }
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
              model: [
                { id: "current", label: "Now" },
                { id: "future", label: "Daily" },
                { id: "hourly", label: "Hourly" },
              ]
              delegate: Rectangle {
              id: weatherTab
              required property var modelData
              Layout.fillWidth: true
              Layout.preferredHeight: 32
              radius: 8
              color: root.weatherForecastMode === modelData.id ? Theme.accent : Theme.surface
              Text {
                anchors.centerIn: parent
                text: modelData.label
                  color: root.weatherForecastMode === modelData.id ? Theme.background : Theme.text
                  font.family: Theme.fontSans
                  font.pixelSize: 12
                  font.bold: root.weatherForecastMode === modelData.id
                }
                MouseArea {
                  id: tabMouse
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.weatherForecastMode = modelData.id
                }
              }
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            GridLayout {
              visible: root.weatherForecastMode === "current"
              anchors.fill: parent
              columns: 2
              rowSpacing: 8
              columnSpacing: 8
              Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 76; radius: Theme.radiusMd; color: Theme.surface
                ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 2
                  Text { text: "Feels like"; color: root.secondaryText; font.family: Theme.font; font.pixelSize: 11 }
                  Text { text: root.weatherData && root.weatherData.apparentTemperature !== null && root.weatherData.apparentTemperature !== undefined ? Math.round(root.weatherData.apparentTemperature) + "°C" : "—"; color: Theme.text; font.family: Theme.font; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                }
              }
              Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 76; radius: Theme.radiusMd; color: Theme.surface
                ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 2
                  Text { text: "Wind"; color: root.secondaryText; font.family: Theme.font; font.pixelSize: 11 }
                  Text { text: root.weatherData && root.weatherData.windSpeed !== null && root.weatherData.windSpeed !== undefined ? Math.round(root.weatherData.windSpeed) + " km/h" : "—"; color: Theme.text; font.family: Theme.font; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                }
              }
              Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 76; radius: Theme.radiusMd; color: Theme.surface
                ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 2
                  Text { text: "Low"; color: root.secondaryText; font.family: Theme.font; font.pixelSize: 11 }
                  Text { text: root.weatherData && root.weatherData.todayMin !== null && root.weatherData.todayMin !== undefined ? Math.round(root.weatherData.todayMin) + "°" : "—"; color: Theme.text; font.family: Theme.font; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                }
              }
              Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 76; radius: Theme.radiusMd; color: Theme.surface
                ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 2
                  Text { text: "High"; color: root.secondaryText; font.family: Theme.font; font.pixelSize: 11 }
                  Text { text: root.weatherData && root.weatherData.todayMax !== null && root.weatherData.todayMax !== undefined ? Math.round(root.weatherData.todayMax) + "°" : "—"; color: Theme.text; font.family: Theme.font; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                }
              }
              Text {
                visible: root.weatherError.length > 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                text: root.weatherError
                color: Theme.danger
                font.family: Theme.fontSans
                font.pixelSize: 11
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }
            }

            ListView {
              visible: root.weatherForecastMode === "future"
              anchors.fill: parent
              clip: true
              spacing: 7
              model: root.weatherData && root.weatherData.dailyForecast ? root.weatherData.dailyForecast : []
              delegate: Rectangle {
                required property var modelData
                readonly property bool isToday: root.weatherIsToday(modelData.date)
                width: ListView.view.width
                height: 44
                radius: 10
                color: isToday ? Theme.accent : Theme.surface
                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 10
                  spacing: 10
                  Text { text: parent.parent.isToday ? "Today" : root.weatherShortDate(parent.parent.modelData.date); color: parent.parent.isToday ? Theme.background : Theme.text; font.family: Theme.font; font.bold: parent.parent.isToday; Layout.preferredWidth: 50 }
                  Text { text: root.weatherGlyphForCode(parent.parent.modelData.weatherCode); color: parent.parent.isToday ? Theme.background : Theme.accent; font.family: Theme.font; font.pixelSize: 17; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignHCenter }
                  Item { Layout.fillWidth: true }
                  Text { text: parent.parent.modelData.minTemperature !== null && parent.parent.modelData.minTemperature !== undefined && parent.parent.modelData.maxTemperature !== null && parent.parent.modelData.maxTemperature !== undefined ? Math.round(parent.parent.modelData.minTemperature) + "°  " + Math.round(parent.parent.modelData.maxTemperature) + "°" : "—"; color: parent.parent.isToday ? Theme.background : Theme.text; font.family: Theme.fontSans; font.bold: true; Layout.preferredWidth: 74; horizontalAlignment: Text.AlignRight }
                }
              }
              Text {
                anchors.centerIn: parent
                visible: parent.count === 0
                text: weatherQuery.running ? "Loading forecast…" : (root.weatherError || "No forecast available")
                color: root.weatherError ? Theme.danger : Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                width: parent.width - 24
                wrapMode: Text.Wrap
              }
            }

            ListView {
              visible: root.weatherForecastMode === "hourly"
              anchors.fill: parent
              clip: true
              spacing: 7
              model: root.weatherData && root.weatherData.hourlyForecast ? root.weatherData.hourlyForecast.slice(0, 12) : []
              delegate: Rectangle {
                required property var modelData
                readonly property bool isCurrentHour: root.weatherIsCurrentHour(modelData.time)
                width: ListView.view.width
                height: 44
                radius: 10
                color: isCurrentHour ? Theme.accent : Theme.surface
                border.color: isCurrentHour ? Theme.accent : Theme.border
                border.width: isCurrentHour ? 0 : 1
                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 10
                  spacing: 10
                  Text { text: parent.parent.isCurrentHour ? "Now" : root.weatherHourLabel(parent.parent.modelData.time); color: parent.parent.isCurrentHour ? Theme.background : Theme.text; font.family: Theme.font; font.bold: parent.parent.isCurrentHour; Layout.preferredWidth: 46 }
                  Text { text: root.weatherGlyphForCode(parent.parent.modelData.weatherCode); color: parent.parent.isCurrentHour ? Theme.background : root.secondaryText; font.family: Theme.font; font.pixelSize: 17; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignHCenter }
                  Text { text: parent.parent.modelData.temperature !== null && parent.parent.modelData.temperature !== undefined ? Math.round(parent.parent.modelData.temperature) + "°C" : "—"; color: parent.parent.isCurrentHour ? Theme.background : Theme.text; font.family: Theme.fontSans; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                  Text { text: parent.parent.modelData.windSpeed !== null && parent.parent.modelData.windSpeed !== undefined ? Math.round(parent.parent.modelData.windSpeed) + " km/h" : "—"; color: parent.parent.isCurrentHour ? Theme.background : root.secondaryText; font.family: Theme.font; font.pixelSize: 11; Layout.preferredWidth: 88; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
                }
              }
              Text {
                anchors.centerIn: parent
                visible: parent.count === 0
                text: weatherQuery.running ? "Loading forecast…" : (root.weatherError || "No hourly forecast")
                color: root.weatherError ? Theme.danger : Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                width: parent.width - 24
                wrapMode: Text.Wrap
              }
            }
          }
        }

        ColumnLayout {
          visible: root.widgetPage === "clipboard"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 10

	            RowLayout {
	              Layout.alignment: Qt.AlignLeft
	              spacing: 8
            TextField {
              Layout.fillWidth: true
              implicitHeight: 38
              text: root.clipboardFilter
              placeholderText: "Search history"
              color: Theme.text
              placeholderTextColor: Theme.muted
              font.family: Theme.font
              font.pixelSize: 12
              cursorDelegate: root.themedCursor
              selectionColor: Theme.accent
              selectedTextColor: Theme.background
              selectByMouse: true
              background: Rectangle {
                radius: 9
                color: Theme.surface
                border.color: parent.activeFocus ? Theme.accent : Theme.border
                border.width: 1
              }
              onTextChanged: root.clipboardFilter = text
              Keys.onEscapePressed: {
                if (root.clipboardFilter.length > 0) root.clipboardFilter = "";
                else root.closeWidget();
              }
            }
            Rectangle {
              Layout.preferredWidth: 38
              Layout.preferredHeight: 38
              radius: 9
              color: Theme.surface
              Text { anchors.centerIn: parent; text: "󰑐"; color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
              MouseArea {
                id: refreshClipboardMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: clipboardQuery.running = true
              }
            }
            Rectangle {
              Layout.preferredWidth: 38
              Layout.preferredHeight: 38
              radius: 9
              color: Theme.surface
              Text { anchors.centerIn: parent; text: "󰆴"; color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
              MouseArea {
                id: clearClipboardMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.runClipboardAction("wipe", null)
              }
            }
          }

          ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 7
            model: root.filteredClipboardEntries()
            delegate: Rectangle {
            id: clipboardRow
            required property var modelData
            width: ListView.view.width
            height: 58
            radius: 10
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
              RowLayout {
                z: 1
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Text {
                  text: "󰅇"
                  color: Theme.accent
                  font.family: Theme.fontIcon
                  font.pixelSize: 18
                  Layout.preferredWidth: 24
                  horizontalAlignment: Text.AlignHCenter
                }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2
                  Text {
                    Layout.fillWidth: true
                    text: clipboardRow.modelData.preview
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    text: "#" + clipboardRow.modelData.id
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: 10
                    elide: Text.ElideRight
                  }
                }
                Rectangle {
                  Layout.preferredWidth: 30
                  Layout.preferredHeight: 30
                  radius: 8
                  color: Theme.background
                  border.color: Theme.border
                  Text { anchors.centerIn: parent; text: "×"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 16 }
                  MouseArea {
                    id: deleteClipboardMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runClipboardAction("delete", clipboardRow.modelData)
                  }
                }
              }
              MouseArea {
                id: clipboardRowMouse
                z: 0
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: root.runClipboardAction("copy", clipboardRow.modelData)
              }
            }
            Text {
              anchors.centerIn: parent
              visible: parent.count === 0
              text: clipboardQuery.running ? "Loading clipboard..." : (root.clipboardStatus || "No matches")
              color: Theme.muted
              font.family: Theme.fontSans
              font.pixelSize: 12
              horizontalAlignment: Text.AlignHCenter
              width: parent.width - 24
              wrapMode: Text.Wrap
            }
          }
        }

        ScrollView {
          id: toolsScroll
          visible: root.widgetPage === "tools"
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: contentHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

          ColumnLayout {
            width: toolsScroll.availableWidth
            spacing: 14
            Text { text: "Screenshot"; color: Theme.muted; font.family: Theme.fontSans; font.bold: true }
            Rectangle {
              Layout.fillWidth: true; implicitHeight: 44; radius: Theme.radiusSm; color: Theme.surface
              Text { anchors.centerIn: parent; text: "󰄀  Select area and edit"; color: Theme.text; font.family: Theme.font }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.captureScreenshot("edit", true) }
            }
          }
        }

        ScrollView {
          id: shutdownScroll
          visible: root.widgetPage === "shutdown"
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: contentHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

          ColumnLayout {
            width: shutdownScroll.availableWidth
            spacing: 10
            Text { text: "Shutdown in"; color: Theme.muted; font.family: Theme.fontSans; font.bold: true }
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 78
              radius: 10
              color: Theme.surface
              RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
              Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 8
                  color: Theme.background
                  border.color: Theme.border
                  Text { anchors.centerIn: parent; text: "−"; color: Theme.text; font.family: Theme.font; font.pixelSize: 20 }
                  MouseArea {
                    id: minusDelayMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setShutdownDelay(root.shutdownDelayMinutes - 5)
                  }
                }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0
                  Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.shutdownDelayLabel()
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 28
                    font.bold: true
                  }
                  Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "relative timer"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: 11
                  }
                }
                Rectangle {
                  Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 8
                  color: Theme.background
                  border.color: Theme.border
                  Text { anchors.centerIn: parent; text: "+"; color: Theme.text; font.family: Theme.font; font.pixelSize: 20 }
                  MouseArea {
                    id: plusDelayMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setShutdownDelay(root.shutdownDelayMinutes + 5)
                  }
                }
              }
            }

	            RowLayout {
	              Layout.fillWidth: true
	              Layout.alignment: Qt.AlignLeft
	              spacing: 8
	              Repeater {
                model: [15, 30, 60, 120]
                delegate: Rectangle {
                  required property int modelData
                  Layout.fillWidth: true
                  Layout.preferredHeight: 34
                  radius: 8
                  color: root.shutdownDelayMinutes === modelData ? Theme.accent : Theme.surface
                  Text {
                    anchors.centerIn: parent
                    text: parent.modelData < 60 ? parent.modelData + "m" : (parent.modelData / 60) + "h"
                    color: root.shutdownDelayMinutes === parent.modelData ? Theme.background : Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                    font.bold: root.shutdownDelayMinutes === parent.modelData
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setShutdownDelay(parent.modelData) }
                }
              }
            }

            Text {
              Layout.fillWidth: true
              text: "Overnight checks still run at 00:00-06:00."
              color: Theme.muted
              font.family: Theme.fontSans
              font.pixelSize: 11
              wrapMode: Text.Wrap
            }

            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 58
              radius: 10
              color: root.shutdownPendingTarget.length > 0 ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.16) : Theme.surface
              border.color: root.shutdownPendingTarget.length > 0 ? Theme.danger : Theme.border
              border.width: 1
              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 2
                Text {
                  Layout.fillWidth: true
                  text: root.shutdownPendingTarget.length > 0 ? "Shutdown " + root.shutdownPendingTarget : "No shutdown timer set"
                  color: root.shutdownPendingTarget.length > 0 ? Theme.danger : Theme.text
                  font.family: Theme.fontSans
                  font.bold: true
                  font.pixelSize: 13
                  elide: Text.ElideRight
                }
                Text {
                  Layout.fillWidth: true
                  text: root.shutdownPendingTarget.length > 0 ? root.shutdownRemainingLabel() + " left" : "Use the timer above to schedule one"
                  color: Theme.muted
                  font.family: Theme.fontSans
                  font.pixelSize: 11
                  elide: Text.ElideRight
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 9
                color: Theme.surface
                Text { anchors.centerIn: parent; text: "󰐥  Set timer"; color: Theme.text; font.family: Theme.fontSans; font.bold: true }
                MouseArea {
                  id: scheduleShutdownMouse
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.scheduleShutdown()
                }
              }
              Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 9
                enabled: root.shutdownPendingTarget.length > 0
                opacity: root.shutdownPendingTarget.length > 0 ? 1 : 0.55
                color: Theme.surface
                Text {
                  anchors.centerIn: parent
                  text: "󰜺  Cancel"
                  color: Theme.text
                  font.family: Theme.fontIcon
                  font.bold: true
                }
                MouseArea {
                  id: cancelShutdownMouse
                  anchors.fill: parent
                  enabled: root.shutdownPendingTarget.length > 0
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: root.cancelPendingShutdown()
                }
              }
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
                for (const annotation of root.screenshotAnnotations)
                  root.screenshotDrawAnnotation(context, annotation, screenshotCanvas, screenshotImage);
                root.screenshotDrawStroke(context, root.screenshotCurrentStroke, screenshotCanvas, screenshotImage);
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: root.screenshotEditMode === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                enabled: root.screenshotPath.length > 0
                onPressed: mouse => {
                  const point = root.screenshotPointFromCanvas(mouse, screenshotCanvas, screenshotImage);
                  if (!point) return;
                  if (root.screenshotEditMode === "text") {
                    root.addScreenshotText(point);
                    return;
                  }
                  root.screenshotCurrentStroke = {
                    type: "stroke",
                    color: root.screenshotInk,
                    width: root.screenshotInkWidth,
                    points: [point]
                  };
                  screenshotCanvas.requestPaint();
                }
                onPositionChanged: mouse => {
                  if (root.screenshotEditMode !== "draw" || !root.screenshotCurrentStroke) return;
                  const point = root.screenshotPointFromCanvas(mouse, screenshotCanvas, screenshotImage);
                  if (!point) return;
                  root.screenshotCurrentStroke.points.push(point);
                  screenshotCanvas.requestPaint();
                }
                onReleased: {
                  if (!root.screenshotCurrentStroke) return;
                  root.screenshotAnnotations = root.screenshotAnnotations.concat([root.screenshotCurrentStroke]);
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
              font.family: Theme.fontSans
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
              model: [
                { key: "draw", label: "Draw" },
                { key: "text", label: "Text" }
              ]
              Rectangle {
                required property var modelData
                Layout.preferredWidth: 84
                implicitHeight: 34
                radius: 8
                color: root.screenshotEditMode === modelData.key ? Theme.accent : Theme.surface
                border.color: root.screenshotEditMode === modelData.key ? Theme.accent : Theme.border
                border.width: 1
                Text {
                  anchors.centerIn: parent
                  text: modelData.label
                  color: root.screenshotEditMode === modelData.key ? Theme.background : Theme.text
                  font.family: Theme.fontSans
                  font.pixelSize: 12
                  font.bold: true
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.screenshotEditMode = parent.modelData.key;
                    root.screenshotCurrentStroke = null;
                    screenshotCanvas.requestPaint();
                  }
                }
              }
            }
            TextField {
              Layout.fillWidth: true
              implicitHeight: 34
              enabled: root.screenshotEditMode === "text"
              text: root.screenshotTextDraft
              placeholderText: "Text to place"
              color: Theme.text
              placeholderTextColor: Theme.muted
              font.family: Theme.font
              font.pixelSize: 12
              cursorDelegate: root.themedCursor
              selectionColor: Theme.accent
              selectedTextColor: Theme.background
              selectByMouse: true
              background: Rectangle {
                radius: 8
                color: Theme.surface
                border.color: parent.activeFocus ? Theme.accent : Theme.border
                border.width: 1
              }
              onTextChanged: root.screenshotTextDraft = text
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "Ink"; color: Theme.muted; font.family: Theme.fontSans; font.bold: true }
            Repeater {
              model: root.screenshotInkColors
              delegate: Rectangle {
                required property string modelData
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: modelData
                border.color: root.screenshotInk === modelData ? Theme.text : Theme.border
                border.width: root.screenshotInk === modelData ? 3 : 1
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.screenshotInk = parent.modelData
                }
              }
            }
            Item { Layout.fillWidth: true }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: root.screenshotEditMode === "text" ? "Text size" : "Brush size"; color: Theme.muted; font.family: Theme.fontSans; font.bold: true }
            Item { Layout.fillWidth: true }
            Slider {
              Layout.preferredWidth: 160
              from: 2
              to: root.screenshotEditMode === "text" ? 96 : 24
              stepSize: 1
              value: root.screenshotEditMode === "text" ? root.screenshotTextSize : root.screenshotInkWidth
              onMoved: {
                if (root.screenshotEditMode === "text") root.screenshotTextSize = Math.round(value);
                else root.screenshotInkWidth = Math.round(value);
              }
            }
            Text {
              Layout.preferredWidth: 34
              horizontalAlignment: Text.AlignRight
              text: (root.screenshotEditMode === "text" ? root.screenshotTextSize : root.screenshotInkWidth) + "px"
              color: Theme.text
              font.family: Theme.fontSans
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
              Layout.fillWidth: true; implicitHeight: 40; radius: Theme.radiusSm; color: Theme.surface
              Text { anchors.centerIn: parent; text: "Undo"; color: Theme.text; font.family: Theme.font }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.screenshotAnnotations.length > 0) {
                    root.screenshotAnnotations = root.screenshotAnnotations.slice(0, root.screenshotAnnotations.length - 1);
                    screenshotCanvas.requestPaint();
                  }
                }
              }
            }
            Rectangle {
              Layout.fillWidth: true; implicitHeight: 40; radius: Theme.radiusSm; color: Theme.surface
              Text { anchors.centerIn: parent; text: "Save"; color: Theme.text; font.family: Theme.font }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveEditedScreenshot() }
            }
            Rectangle {
              Layout.fillWidth: true; implicitHeight: 40; radius: Theme.radiusSm; color: Theme.surface
              Text { anchors.centerIn: parent; text: "Copy"; color: Theme.text; font.family: Theme.font }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.copyEditedScreenshot() }
            }
            Rectangle {
              Layout.fillWidth: true; implicitHeight: 40; radius: Theme.radiusSm; color: Theme.surface
              Text { anchors.centerIn: parent; text: "Retake"; color: Theme.accent; font.family: Theme.font }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.captureScreenshot("edit", true) }
            }
          }
        }

        ColumnLayout {
          visible: root.widgetPage === "calendar"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
	          RowLayout {
	            Layout.fillWidth: true
	            Text {
	              text: Qt.formatDateTime(new Date(root.calendarSelectedDate + "T00:00:00"), "dddd, d MMMM")
	              color: Theme.muted
	              font.family: Theme.fontSans
	              Layout.fillWidth: true
	            }
	          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
	            RowLayout {
	              Layout.fillWidth: true
	              Layout.preferredHeight: 30
	              spacing: 8
	              Text {
	                text: root.calendarEditingHref.length > 0 ? "Editing " + root.calendarEditingKind : ""
	                color: Theme.accent
	                font.family: Theme.fontSans
	                font.pixelSize: 11
	                font.bold: true
	                Layout.fillWidth: true
	                verticalAlignment: Text.AlignVCenter
	              }
	              Rectangle {
	                implicitWidth: 78
	                implicitHeight: 30
		                radius: Theme.radiusSm
		                color: root.calendarCanUndo ? Theme.surface : "transparent"
		                border.color: root.calendarCanUndo ? Theme.border : "transparent"
		                border.width: 1
		                Text { anchors.fill: parent; text: "Undo"; color: root.calendarCanUndo ? Theme.accent : "transparent"; font.family: Theme.fontSans; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
	                MouseArea {
	                  anchors.fill: parent
	                  enabled: root.calendarCanUndo && !calendarTaskAction.running
	                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
	                  onClicked: root.undoCalendarChange()
	                }
	              }
	              Rectangle {
	                implicitWidth: 92
	                implicitHeight: 30
		                radius: Theme.radiusSm
		                color: root.calendarEditingHref.length > 0 ? Theme.surface : "transparent"
		                Text { anchors.fill: parent; text: "Cancel"; color: root.calendarEditingHref.length > 0 ? Theme.text : "transparent"; font.family: Theme.fontSans; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
	                MouseArea { anchors.fill: parent; enabled: root.calendarEditingHref.length > 0; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.resetCalendarEditor() }
	              }
	              Rectangle {
	                implicitWidth: 80
	                implicitHeight: 30
		                radius: Theme.radiusSm
		                color: root.calendarEditingHref.length > 0 ? Theme.danger : "transparent"
		                Text { anchors.fill: parent; text: "Delete"; color: root.calendarEditingHref.length > 0 ? Theme.text : "transparent"; font.family: Theme.fontSans; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
	                MouseArea {
	                  anchors.fill: parent
	                  enabled: root.calendarEditingHref.length > 0 && !calendarTaskAction.running
	                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
	                  onClicked: root.deleteCalendarItem(root.calendarEditingHref)
	                }
              }
            }
			            RowLayout {
			              Layout.alignment: Qt.AlignLeft
			              Layout.leftMargin: 135
			              spacing: 8
              Repeater {
                model: [
                  { key: "task", label: "Task" },
                  { key: "event", label: "Event" }
                ]
	                Rectangle {
	                  required property var modelData
	                  implicitWidth: 72
	                  implicitHeight: 40
	                  radius: 8
                  color: root.calendarEntryMode === modelData.key ? Theme.accent : Theme.surface
                  border.color: root.calendarEntryMode === modelData.key ? Theme.accent : Theme.border
                  border.width: 1
                  Text {
		                    anchors.fill: parent
		                    text: modelData.label
		                    color: root.calendarEntryMode === modelData.key ? Theme.background : Theme.text
		                    font.family: Theme.fontSans
		                    font.pixelSize: 14
		                    font.bold: true
		                    horizontalAlignment: Text.AlignHCenter
		                    verticalAlignment: Text.AlignVCenter
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.resetCalendarEditor();
                      root.calendarEntryMode = parent.modelData.key;
                    }
                  }
                }
	              }
              TextField {
                Layout.preferredWidth: 360
                Layout.maximumWidth: 360
                implicitHeight: 40
                text: root.calendarTitleDraft
                placeholderText: root.calendarEntryMode === "event" ? "Add event" : "Add task"
                color: Theme.text
                placeholderTextColor: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
                cursorDelegate: root.themedCursor
                selectionColor: Theme.accent
                selectedTextColor: Theme.background
                selectByMouse: true
                background: Rectangle {
                  radius: 9
                  color: Theme.surface
                  border.color: parent.activeFocus ? Theme.accent : Theme.border
                  border.width: 1
                }
                onTextChanged: root.calendarTitleDraft = text
                Keys.onReturnPressed: root.addCalendarItem()
                Keys.onEnterPressed: root.addCalendarItem()
              }
		              Rectangle {
		                implicitWidth: 40
		                implicitHeight: 40
		                radius: 9
                color: root.calendarTitleDraft.trim().length > 0 ? Theme.accent : Theme.surface
	                Text {
		                  anchors.fill: parent
		                  text: root.calendarSaveLabel()
		                  color: root.calendarTitleDraft.trim().length > 0 ? Theme.background : Theme.muted
		                  font.family: Theme.fontSans
			                  font.pixelSize: root.calendarEditingHref.length > 0 ? 11 : 18
	                  font.bold: true
	                  horizontalAlignment: Text.AlignHCenter
	                  verticalAlignment: Text.AlignVCenter
                }
                MouseArea {
                  anchors.fill: parent
                  enabled: root.calendarTitleDraft.trim().length > 0 && !calendarTaskAction.running
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
		                  onClicked: root.addCalendarItem()
		                }
		              }
			              Rectangle {
			                implicitWidth: 78
			                implicitHeight: 40
		                radius: 8
		                color: root.calendarEntryMode === "event" ? (root.calendarAllDay ? Theme.accent : Theme.surface) : "transparent"
		                border.color: root.calendarEntryMode === "event" ? (root.calendarAllDay ? Theme.accent : Theme.border) : "transparent"
	                border.width: 1
	                RowLayout {
	                  anchors.centerIn: parent
	                  spacing: 6
		                  Text { text: root.calendarEntryMode === "event" && root.calendarAllDay ? "✓" : ""; color: root.calendarEntryMode === "event" ? (root.calendarAllDay ? Theme.background : Theme.muted) : "transparent"; font.family: Theme.fontSans; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
		                  Text { text: "All day"; color: root.calendarEntryMode === "event" ? (root.calendarAllDay ? Theme.background : Theme.text) : "transparent"; font.family: Theme.fontSans; font.pixelSize: 11; font.bold: true; verticalAlignment: Text.AlignVCenter }
		                }
		                MouseArea { anchors.fill: parent; enabled: root.calendarEntryMode === "event"; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.calendarAllDay = !root.calendarAllDay }
		              }
				              ColumnLayout {
					                Layout.preferredWidth: 260
					                Layout.maximumWidth: 260
				                Layout.preferredHeight: 40
				                spacing: 4
				                RowLayout {
				                  Layout.fillWidth: true
				                  Layout.preferredHeight: 18
					                  spacing: 5
				                  Text {
				                    text: "Start"
				                    color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.muted : "transparent"
				                    font.family: Theme.fontSans
				                    font.pixelSize: 12
				                    font.bold: true
				                    Layout.preferredWidth: 36
				                    horizontalAlignment: Text.AlignRight
				                    verticalAlignment: Text.AlignVCenter
				                  }
					                  Rectangle {
					                    implicitWidth: 24
					                    implicitHeight: 18
				                    radius: 5
				                    color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.surface : "transparent"
				                    border.color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.border : "transparent"
				                    border.width: 1
						                    Text { anchors.fill: parent; text: "-"; color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.text : "transparent"; font.family: Theme.font; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
				                    MouseArea { anchors.fill: parent; enabled: root.calendarEntryMode === "event" && !root.calendarAllDay; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onPressed: root.startCalendarTimeRepeat("start", -15); onReleased: root.stopCalendarTimeRepeat(); onCanceled: root.stopCalendarTimeRepeat() }
				                  }
				                  Rectangle {
				                    Layout.fillWidth: true
				                    implicitHeight: 18
				                    radius: 5
				                    color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.surface : "transparent"
				                    border.color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.accent : "transparent"
				                    border.width: 1
						                    Text { anchors.fill: parent; text: root.calendarClock(root.calendarEventStartMinutes); color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.text : "transparent"; font.family: Theme.font; font.pixelSize: 15; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
				                  }
				                  Rectangle {
				                    implicitWidth: 24
				                    implicitHeight: 18
				                    radius: 5
				                    color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.surface : "transparent"
				                    border.color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.border : "transparent"
				                    border.width: 1
						                    Text { anchors.fill: parent; text: "+"; color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.text : "transparent"; font.family: Theme.font; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
				                    MouseArea { anchors.fill: parent; enabled: root.calendarEntryMode === "event" && !root.calendarAllDay; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onPressed: root.startCalendarTimeRepeat("start", 15); onReleased: root.stopCalendarTimeRepeat(); onCanceled: root.stopCalendarTimeRepeat() }
				                  }
				                }
				                RowLayout {
				                  Layout.fillWidth: true
				                  Layout.preferredHeight: 18
					                  spacing: 5
				                  Text {
				                    text: "End"
				                    color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.muted : "transparent"
				                    font.family: Theme.fontSans
				                    font.pixelSize: 12
				                    font.bold: true
				                    Layout.preferredWidth: 36
				                    horizontalAlignment: Text.AlignRight
				                    verticalAlignment: Text.AlignVCenter
				                  }
					                  Rectangle {
					                    implicitWidth: 24
				                    implicitHeight: 18
				                    radius: 5
				                    color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.surface : "transparent"
				                    border.color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.border : "transparent"
				                    border.width: 1
						                    Text { anchors.fill: parent; text: "-"; color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.text : "transparent"; font.family: Theme.font; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
				                    MouseArea { anchors.fill: parent; enabled: root.calendarEntryMode === "event" && !root.calendarAllDay; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onPressed: root.startCalendarTimeRepeat("duration", -15); onReleased: root.stopCalendarTimeRepeat(); onCanceled: root.stopCalendarTimeRepeat() }
				                  }
				                  Rectangle {
				                    Layout.fillWidth: true
				                    implicitHeight: 18
				                    radius: 5
				                    color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.surface : "transparent"
				                    border.color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.accent : "transparent"
				                    border.width: 1
						                    Text { anchors.fill: parent; text: root.calendarEndClock() + "  " + root.calendarEventDurationMinutes + "m"; color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.text : "transparent"; font.family: Theme.font; font.pixelSize: 15; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
				                  }
				                  Rectangle {
				                    implicitWidth: 24
				                    implicitHeight: 18
				                    radius: 5
				                    color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.surface : "transparent"
				                    border.color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.border : "transparent"
				                    border.width: 1
						                    Text { anchors.fill: parent; text: "+"; color: root.calendarEntryMode === "event" && !root.calendarAllDay ? Theme.text : "transparent"; font.family: Theme.font; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
				                    MouseArea { anchors.fill: parent; enabled: root.calendarEntryMode === "event" && !root.calendarAllDay; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onPressed: root.startCalendarTimeRepeat("duration", 15); onReleased: root.stopCalendarTimeRepeat(); onCanceled: root.stopCalendarTimeRepeat() }
				                  }
				                }
				              }
	            }
            Rectangle {
              visible: root.calendarError.length > 0
              Layout.fillWidth: true
              implicitHeight: 30
              radius: Theme.radiusSm
              color: Theme.surface
              border.color: Theme.accent
              border.width: 1
              Text {
                anchors.fill: parent
                anchors.margins: 8
                text: root.calendarError
                color: Theme.accent
                font.family: Theme.fontSans
                font.pixelSize: 10
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
              }
            }
          }
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
	            ColumnLayout {
                  id: calendarMonthColumn
                  Layout.preferredWidth: 1700
                  Layout.maximumWidth: 1700
	              Layout.fillHeight: true
	              spacing: 10
	              RowLayout {
	                Layout.fillWidth: true
	                spacing: 10
	                Rectangle {
	                  implicitWidth: 40
	                  implicitHeight: 40
	                  radius: 8
	                  color: Theme.surface
	                  border.color: Theme.border
	                  border.width: 1
	                  Text { anchors.fill: parent; text: "‹"; color: Theme.text; font.family: Theme.fontSans; font.pixelSize: 24; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
	                  MouseArea {
	                    anchors.fill: parent
	                    cursorShape: Qt.PointingHandCursor
	                    onClicked: root.calendarMonthOffset--
	                  }
	                }
		                Text {
		                  Layout.fillWidth: true
		                  text: Qt.formatDateTime(root.calendarDisplayDate(), "MMMM yyyy")
	                  color: Theme.text
	                  font.family: Theme.fontSans
	                  font.pixelSize: 20
	                  font.bold: true
		                  horizontalAlignment: Text.AlignHCenter
		                  verticalAlignment: Text.AlignVCenter
		                }
		                Rectangle {
		                  implicitWidth: 70
		                  implicitHeight: 40
		                  radius: 8
		                  color: Theme.surface
		                  border.color: Theme.border
		                  border.width: 1
		                  Text { anchors.fill: parent; text: "Today"; color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
		                  MouseArea {
		                    anchors.fill: parent
		                    cursorShape: Qt.PointingHandCursor
		                    onClicked: {
		                      root.calendarMonthOffset = 0;
		                      root.calendarSelectedDate = root.dateKey(clock.date);
		                    }
		                  }
		                }
		                Rectangle {
		                  implicitWidth: 40
		                  implicitHeight: 40
	                  radius: 8
	                  color: Theme.surface
	                  border.color: Theme.border
	                  border.width: 1
	                  Text { anchors.fill: parent; text: "›"; color: Theme.text; font.family: Theme.fontSans; font.pixelSize: 24; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
	                  MouseArea {
	                    anchors.fill: parent
	                    cursorShape: Qt.PointingHandCursor
	                    onClicked: root.calendarMonthOffset++
	                  }
	                }
	              }
	              GridLayout {
                id: calendarMonthGrid
                readonly property int cellSize: 184
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                columns: 7; rowSpacing: 8; columnSpacing: 8
            Repeater {
              model: ["M", "T", "W", "T", "F", "S", "S"]
              Text {
                required property string modelData
                text: modelData
                color: Theme.accent
                font.family: Theme.fontSans
                font.bold: true
		                font.pixelSize: 14
	                Layout.preferredWidth: calendarMonthGrid.cellSize
	                Layout.preferredHeight: 22
                horizontalAlignment: Text.AlignHCenter
              }
            }
            Repeater {
	              model: root.monthCells()
	              Rectangle {
	                id: calendarDayCell
	                required property var modelData
                Layout.preferredWidth: calendarMonthGrid.cellSize
                Layout.preferredHeight: calendarMonthGrid.cellSize
                implicitWidth: calendarMonthGrid.cellSize
                implicitHeight: calendarMonthGrid.cellSize
                radius: 8
                color: !modelData.inMonth ? "transparent" : modelData.isSelected ? Theme.accent : Theme.surface
                border.color: modelData.inMonth && (modelData.isToday || modelData.eventCount > 0) && !modelData.isSelected ? Theme.accent : "transparent"
                border.width: modelData.inMonth && (modelData.isToday || modelData.eventCount > 0) && !modelData.isSelected ? 1 : 0
                Text {
                  anchors.left: parent.left
                  anchors.top: parent.top
	                  anchors.leftMargin: 13
	                  anchors.topMargin: 10
                  text: modelData.inMonth ? modelData.day : ""
                  color: modelData.isSelected ? Theme.background : Theme.text
                  font.family: Theme.fontSans
		                  font.pixelSize: 22
                  font.bold: modelData.isToday || modelData.isSelected
                }
                Flickable {
                  id: calendarDayScroll
                  visible: modelData.inMonth && (modelData.eventCount > 0 || modelData.isToday)
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.topMargin: 44
                  anchors.leftMargin: 12
                  anchors.rightMargin: 8
                  anchors.bottomMargin: 10
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  contentWidth: width
                  contentHeight: calendarDayEventColumn.implicitHeight

                  Column {
                    id: calendarDayEventColumn
                    width: calendarDayScroll.width - (calendarDayScroll.contentHeight > calendarDayScroll.height ? 8 : 0)
                    spacing: 5
                    Repeater {
                      model: root.calendarDayItems(calendarDayCell.modelData.date)
                      Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 20
                        radius: 5
                        color: modelData.nowMarker ? "#f38ba8" : (calendarDayCell.modelData.isSelected ? Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.28) : (modelData.completed ? Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.14) : (modelData.task ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24) : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10))))
                        Text {
                          anchors.fill: parent
                          anchors.leftMargin: 7
                          anchors.rightMargin: 7
                          text: modelData.nowMarker ? "now " + modelData.title : ((modelData.task ? (modelData.completed ? "✓ " : "○ ") : (modelData.startTime ? modelData.startTime + " " : "")) + modelData.title)
                          color: modelData.nowMarker ? Theme.background : (calendarDayCell.modelData.isSelected ? Theme.background : (modelData.completed ? Theme.muted : Theme.text))
                          font.family: Theme.fontSans
                          font.pixelSize: 12
                          font.bold: Boolean(modelData.nowMarker)
                          font.strikeout: Boolean(modelData.completed)
                          elide: Text.ElideRight
                          verticalAlignment: Text.AlignVCenter
                        }
                      }
                    }
                  }

                  ScrollBar.vertical: ScrollBar {
                    policy: calendarDayScroll.contentHeight > calendarDayScroll.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    width: 4
                    contentItem: Rectangle {
                      implicitWidth: 4
                      radius: 2
                      color: calendarDayCell.modelData.isSelected ? Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.36) : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.28)
                    }
                    background: Item {}
                  }
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
            }
            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: 10
              Text {
                Layout.fillWidth: true
                text: "Selected day"
                color: Theme.muted
                font.family: Theme.fontSans
                font.bold: true
              }
              RowLayout {
                visible: false
                Layout.fillWidth: true
                spacing: 8
            Repeater {
              model: [
                { key: "task", label: "Task" },
                { key: "event", label: "Event" }
              ]
              Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 8
                color: root.calendarEntryMode === modelData.key ? Theme.accent : Theme.surface
                border.color: root.calendarEntryMode === modelData.key ? Theme.accent : Theme.border
                border.width: 1
                Text {
                  anchors.centerIn: parent
                  text: modelData.label
                  color: root.calendarEntryMode === modelData.key ? Theme.background : Theme.text
                  font.family: Theme.fontSans
                  font.pixelSize: 12
                  font.bold: true
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.resetCalendarEditor();
                    root.calendarEntryMode = parent.modelData.key;
                  }
                }
              }
            }
          }
          Text {
            visible: false
            Layout.fillWidth: true
            text: "Editing " + root.calendarEditingKind
            color: Theme.accent
            font.family: Theme.fontSans
            font.pixelSize: 11
            font.bold: true
          }
          RowLayout {
            visible: false
            Layout.fillWidth: true
            spacing: 8
            TextField {
              Layout.fillWidth: true
              implicitHeight: 38
            text: root.calendarTitleDraft
            placeholderText: root.calendarEntryMode === "event" ? "Add event" : "Add task"
            color: Theme.text
            placeholderTextColor: Theme.muted
            font.family: Theme.font
            font.pixelSize: 12
            cursorDelegate: root.themedCursor
            selectionColor: Theme.accent
            selectedTextColor: Theme.background
            selectByMouse: true
            background: Rectangle {
                radius: 9
                color: Theme.surface
                border.color: parent.activeFocus ? Theme.accent : Theme.border
                border.width: 1
              }
              onTextChanged: root.calendarTitleDraft = text
              Keys.onReturnPressed: root.addCalendarItem()
              Keys.onEnterPressed: root.addCalendarItem()
            }
            Rectangle {
              implicitWidth: 42
              implicitHeight: 38
              radius: 9
              color: root.calendarTitleDraft.trim().length > 0 ? Theme.accent : Theme.surface
              Text {
                anchors.centerIn: parent
                text: root.calendarSaveLabel()
                color: root.calendarTitleDraft.trim().length > 0 ? Theme.background : Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: root.calendarEditingHref.length > 0 ? 11 : 18
                font.bold: true
              }
              MouseArea {
                anchors.fill: parent
                enabled: root.calendarTitleDraft.trim().length > 0 && !calendarTaskAction.running
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.addCalendarItem()
              }
            }
          }
          RowLayout {
            visible: false
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
              implicitWidth: 88
              implicitHeight: 34
              radius: 8
              color: root.calendarAllDay ? Theme.accent : Theme.surface
              border.color: root.calendarAllDay ? Theme.accent : Theme.border
              border.width: 1
              RowLayout {
                anchors.centerIn: parent
                spacing: 6
                Text { text: root.calendarAllDay ? "✓" : ""; color: root.calendarAllDay ? Theme.background : Theme.muted; font.family: Theme.fontSans; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 12; horizontalAlignment: Text.AlignHCenter }
                Text { text: "All day"; color: root.calendarAllDay ? Theme.background : Theme.text; font.family: Theme.fontSans; font.pixelSize: 11; font.bold: true }
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.calendarAllDay = !root.calendarAllDay }
            }
            RowLayout {
              visible: !root.calendarAllDay
              Layout.fillWidth: true
              spacing: 6
              Rectangle {
                implicitWidth: 30
                implicitHeight: 34
                radius: 8
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
	                  Text { anchors.fill: parent; text: "-"; color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: root.startCalendarTimeRepeat("start", -15); onReleased: root.stopCalendarTimeRepeat(); onCanceled: root.stopCalendarTimeRepeat() }
              }
              Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 8
                color: Theme.surface
                border.color: Theme.accent
                border.width: 1
	                  Text { anchors.fill: parent; text: "Start " + root.calendarClock(root.calendarEventStartMinutes); color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
              }
              Rectangle {
                implicitWidth: 30
                implicitHeight: 34
                radius: 8
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
	                  Text { anchors.fill: parent; text: "+"; color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: root.startCalendarTimeRepeat("start", 15); onReleased: root.stopCalendarTimeRepeat(); onCanceled: root.stopCalendarTimeRepeat() }
              }
              Rectangle {
                implicitWidth: 30
                implicitHeight: 34
                radius: 8
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
	                  Text { anchors.fill: parent; text: "-"; color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: root.startCalendarTimeRepeat("duration", -15); onReleased: root.stopCalendarTimeRepeat(); onCanceled: root.stopCalendarTimeRepeat() }
              }
              Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 8
                color: Theme.surface
                border.color: Theme.accent
                border.width: 1
	                  Text { anchors.fill: parent; text: root.calendarEventDurationMinutes + "m -> " + root.calendarEndClock(); color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
              }
              Rectangle {
                implicitWidth: 30
                implicitHeight: 34
                radius: 8
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
	                  Text { anchors.fill: parent; text: "+"; color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onPressed: root.startCalendarTimeRepeat("duration", 15); onReleased: root.stopCalendarTimeRepeat(); onCanceled: root.stopCalendarTimeRepeat() }
              }
            }
          }
          Rectangle {
            visible: false
            Layout.fillWidth: true
            implicitHeight: 34
            radius: Theme.radiusSm
            color: Theme.surface
            border.color: Theme.accent
            border.width: 1
            Text {
              anchors.fill: parent
              anchors.margins: 8
              text: root.calendarError
              color: Theme.accent
              font.family: Theme.fontSans
              font.pixelSize: 10
              elide: Text.ElideRight
              verticalAlignment: Text.AlignVCenter
            }
          }
          RowLayout {
            visible: false
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 34
              radius: Theme.radiusSm
              color: Theme.surface
              Text { anchors.centerIn: parent; text: "Cancel edit"; color: Theme.text; font.family: Theme.fontSans; font.pixelSize: 11; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.resetCalendarEditor() }
            }
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 34
              radius: Theme.radiusSm
              color: Theme.danger
              Text { anchors.centerIn: parent; text: "Delete"; color: Theme.text; font.family: Theme.fontSans; font.pixelSize: 11; font.bold: true }
              MouseArea {
                anchors.fill: parent
                enabled: !calendarTaskAction.running
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.deleteCalendarItem(root.calendarEditingHref)
              }
            }
          }
          ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 96; clip: true; spacing: 6
            model: root.selectedDayEvents()
            delegate: Rectangle {
              id: calendarItemRow
              required property var modelData
              readonly property bool editable: Boolean(modelData.href) && !modelData.note && modelData.source !== "Obsidian"
              readonly property bool noteOpenable: Boolean(modelData.note) && Boolean(modelData.noteId)
              width: ListView.view.width
              implicitHeight: 58
              radius: 9
	              color: root.calendarEditingHref === modelData.href ? Theme.surfaceAlt : (modelData.completed ? Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.10) : Theme.surface)
              RowLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 10
                ColumnLayout {
                  spacing: 0
                  Text { text: Qt.formatDateTime(new Date(modelData.date + "T00:00:00"), "dd"); color: Theme.accent; font.family: Theme.font; font.pixelSize: 18; font.bold: true }
                  Text { text: Qt.formatDateTime(new Date(modelData.date + "T00:00:00"), "MMM"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
                }
	                Text { text: modelData.title; color: modelData.completed ? Theme.muted : Theme.text; font.family: Theme.font; Layout.fillWidth: true; elide: Text.ElideRight; font.strikeout: Boolean(modelData.completed) }
	                Text {
	                  text: modelData.note ? "note" : (modelData.task ? (modelData.completed ? "done" : "task") : (modelData.allDay ? "all day" : (modelData.startTime || "")))
	                  color: Theme.muted
                  font.family: Theme.fontSans
                  font.pixelSize: 10
                }
                Rectangle {
                  visible: calendarItemRow.noteOpenable
                  implicitWidth: 64
                  implicitHeight: 32
                  radius: 8
                  color: Theme.surfaceAlt
                  Text {
		                    anchors.fill: parent
		                    text: "Open"
		                    color: Theme.text
		                    font.family: Theme.fontSans
		                    font.pixelSize: 12
		                    font.bold: true
		                    horizontalAlignment: Text.AlignHCenter
		                    verticalAlignment: Text.AlignVCenter
                  }
                  MouseArea {
                    id: openNoteMouse
                    anchors.fill: parent
                    enabled: calendarItemRow.noteOpenable && !calendarTaskAction.running
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.openCalendarNote(calendarItemRow.modelData.noteId)
                  }
                }
                Rectangle {
                  visible: calendarItemRow.editable
                  implicitWidth: 58
                  implicitHeight: 32
                  radius: 8
                  color: Theme.surfaceAlt
                  Text {
		                    anchors.fill: parent
		                    text: "Edit"
		                    color: Theme.text
		                    font.family: Theme.fontSans
		                    font.pixelSize: 12
		                    font.bold: true
		                    horizontalAlignment: Text.AlignHCenter
		                    verticalAlignment: Text.AlignVCenter
                  }
                  MouseArea {
                    id: editCalendarMouse
                    anchors.fill: parent
                    enabled: calendarItemRow.editable && !calendarTaskAction.running
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.editCalendarItem(calendarItemRow.modelData)
                  }
                }
                Rectangle {
                  visible: calendarItemRow.editable
                  implicitWidth: 72
                  implicitHeight: 32
                  radius: 8
                  color: Theme.surfaceAlt
                  Text {
		                    anchors.fill: parent
		                    text: "Remove"
		                    color: Theme.muted
		                    font.family: Theme.fontSans
		                    font.pixelSize: 12
		                    font.bold: true
		                    horizontalAlignment: Text.AlignHCenter
		                    verticalAlignment: Text.AlignVCenter
                  }
                  MouseArea {
                    id: deleteCalendarMouse
                    anchors.fill: parent
                    enabled: calendarItemRow.editable && !calendarTaskAction.running
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.deleteCalendarItem(calendarItemRow.modelData.href)
                  }
                }
                Rectangle {
		                  visible: Boolean(modelData.task) && !Boolean(modelData.completed) && calendarItemRow.editable
                  implicitWidth: 30
                  implicitHeight: 30
                  radius: 15
                  color: Theme.accent
                  Text {
	                    anchors.fill: parent
	                    text: "✓"
	                    color: Theme.background
	                    font.family: Theme.fontSans
	                    font.pixelSize: 14
	                    font.bold: true
	                    horizontalAlignment: Text.AlignHCenter
	                    verticalAlignment: Text.AlignVCenter
                  }
                  MouseArea {
                    anchors.fill: parent
                    enabled: !calendarTaskAction.running
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.completeCalendarTask(modelData.href)
                  }
                }
              }
            }
            Text {
              anchors.centerIn: parent
              visible: parent.count === 0
              text: "No events or tasks"
              color: Theme.muted
              font.family: Theme.fontSans
              font.pixelSize: 12
              horizontalAlignment: Text.AlignHCenter
            }
          }
            }
          }
	        }
      }
      Keys.onEscapePressed: root.closeWidget()
      Keys.onPressed: event => {
        if (root.widgetPage !== "screenshot" || !(event.modifiers & Qt.ControlModifier)) return;
        if (event.key === Qt.Key_C) {
          root.copyEditedScreenshot();
          event.accepted = true;
        } else if (event.key === Qt.Key_S) {
          root.saveEditedScreenshot();
          event.accepted = true;
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
      radius: Theme.radiusMd; color: Theme.panel; border.color: Theme.border; border.width: 1
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.notificationPopupVisible = false
      }
      RowLayout {
        anchors.fill: parent; anchors.margins: Theme.padMd; spacing: Theme.gapMd
        IconImage {
          visible: root.latestNotification && root.latestNotification.appIcon
          implicitSize: 42
          source: root.latestNotification ? Quickshell.iconPath(root.latestNotification.appIcon, "dialog-information") : ""
        }
        ColumnLayout {
          Layout.fillWidth: true; Layout.fillHeight: true; spacing: 4
          RowLayout {
            Layout.fillWidth: true
            Text { text: root.latestNotification ? root.latestNotification.appName : ""; color: Theme.accent; font.family: Theme.font; font.pixelSize: 11; Layout.fillWidth: true }
            Text { text: root.latestNotification ? root.notificationTimeLabel(root.latestNotification) : ""; color: root.secondaryText; font.family: Theme.font; font.pixelSize: 10 }
          }
          Text { Layout.fillWidth: true; text: root.latestNotification ? root.latestNotification.summary : ""; color: Theme.text; font.family: Theme.fontSans; font.bold: true; font.pixelSize: 14; wrapMode: Text.Wrap }
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
      anchors.fill: parent; radius: Theme.radiusMd; color: Theme.panel; border.color: Theme.border; border.width: 1
      RowLayout {
        anchors.fill: parent; anchors.margins: 14; spacing: 12
        Text {
          text: root.osdKind === "brightness" ? "󰃠" : (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted ? "󰝟" : "")
          color: Theme.accent; font.family: Theme.fontIcon; font.pixelSize: 22
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
      border.color: root.toolBusy ? Theme.accent : Theme.border
      border.width: 1
      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        Text {
          text: root.toolStatusTitle === "Voice to text" ? "󰍬" : "󰄀"
          color: Theme.accent
          font.family: Theme.fontIcon
          font.pixelSize: 24
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text { text: root.toolStatusTitle; color: Theme.text; font.family: Theme.fontSans; font.bold: true }
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
        rightMargin: 54
        bottomMargin: 18
      }
      radius: Theme.radiusLg; color: Theme.panel; border.color: Theme.border; border.width: 1
      ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.padMd; spacing: Theme.gapSm
        RowLayout {
          Layout.fillWidth: true
          Text { text: "Notifications"; color: Theme.text; font.family: Theme.fontSans; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true }
          Text {
            text: "Clear"; color: Theme.accent; font.family: Theme.fontSans
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const copy = notificationServer.trackedNotifications.values.slice(); for (const n of copy) n.dismiss(); } }
          }
        }
        ListView {
          Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8; clip: true
          model: notificationServer.trackedNotifications
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width; height: content.implicitHeight + 24
            radius: Theme.radiusMd; color: Theme.surface
            scale: 1
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: parent.modelData.dismiss()
            }
            ColumnLayout {
              id: content
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 4
              RowLayout {
                Layout.fillWidth: true
                Text { text: parent.parent.parent.modelData.appName; color: Theme.accent; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                Text { text: root.notificationTimeLabel(parent.parent.parent.modelData); color: root.secondaryText; font.family: Theme.font; font.pixelSize: 10 }
                Text { text: "×"; color: Theme.muted; font.pixelSize: 18; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.parent.parent.modelData.dismiss() } }
              }
              Text { Layout.fillWidth: true; text: parent.parent.modelData.summary; color: Theme.text; font.family: Theme.fontSans; font.bold: true; wrapMode: Text.Wrap }
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

    KeybindHelpWindow { shell: root }

    LauncherWindow { shell: root }

    PowerMenuWindow { shell: root; sessionLock: sessionLock }
}
