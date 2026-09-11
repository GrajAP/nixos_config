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

  readonly property var webEngines: [
    { prefix: "g", name: "Google", url: "https://www.google.com/search?q=" },
    { prefix: "gh", name: "GitHub", url: "https://github.com/search?q=" },
    { prefix: "yt", name: "YouTube", url: "https://www.youtube.com/results?search_query=" },
    { prefix: "w", name: "Wikipedia", url: "https://en.wikipedia.org/wiki/Special:Search?search=" },
    { prefix: "r", name: "Reddit", url: "https://www.reddit.com/search/?q=" }
  ]
  readonly property var sysCommands: [
    { id: "lock", title: "Lock screen", subtitle: "Lock the session", glyph: "󰌾", danger: false, match: ["lock", "screen"] },
    { id: "suspend", title: "Suspend", subtitle: "Lock and sleep", glyph: "󰤄", danger: false, match: ["suspend", "sleep"] },
    { id: "logout", title: "Log out", subtitle: "End desktop session", glyph: "󰍃", danger: true, match: ["logout", "log out", "exit", "sign out"] },
    { id: "reboot", title: "Restart", subtitle: "Reboot the system", glyph: "󰜉", danger: true, match: ["reboot", "restart"] },
    { id: "poweroff", title: "Shut down", subtitle: "Power off the system", glyph: "󰐥", danger: true, match: ["shutdown", "shut down", "poweroff", "power off", "halt"] },
    { id: "clipboard", title: "Clipboard history", subtitle: "Open clipboard widget", glyph: "󰅇", danger: false, match: ["clipboard", "clip", "history", "paste"] },
    { id: "screenshot", title: "Screenshot", subtitle: "Select area and edit", glyph: "󰄀", danger: false, match: ["screenshot", "capture", "snip", "shot"] }
  ]

  onVisibleChanged: {
    if (visible) {
      search.text = "";
      appList.currentIndex = 0;
      if (shell && shell.refreshClipboard) shell.refreshClipboard();
    }
  }

  function isClipboardMode(q) {
    const l = q.toLowerCase();
    return l === "cb" || l.startsWith("cb ");
  }

  function detectWebEngine(q) {
    const m = q.match(/^([a-z]{1,2})\s+(.+)$/i);
    if (!m) return null;
    const engine = webEngines.find(e => e.prefix === m[1].toLowerCase());
    if (!engine || !m[2].trim()) return null;
    return { engine: engine, query: m[2].trim() };
  }

  function looksLikeUrl(q) {
    if (!q || /\s/.test(q)) return false;
    return /^(https?:\/\/)?[a-z0-9-]+(\.[a-z0-9-]+)+(:\d+)?(\/\S*)?$/i.test(q);
  }

  function normalizeUrl(q) {
    return /^https?:\/\//i.test(q) ? q : "https://" + q;
  }

  function matchingCommands(q) {
    if (!q || isClipboardMode(q) || detectWebEngine(q)) return [];
    const l = q.toLowerCase();
    return sysCommands.filter(c =>
      c.match.some(k => k.startsWith(l) || (l.length > 1 && (l.startsWith(k) || k.includes(l) || l.includes(k))))
    ).slice(0, 4);
  }

  function tryCalculate(q) {
    const s = q.trim().toLowerCase();
    if (!s || !/[0-9]/.test(s)) return "";
    if (/[^0-9a-z\s+\-*/^().,%]/.test(s)) return "";
    const needsOp = /[+\-*/^%()]/.test(s) || /\b(sqrt|cbrt|sin|cos|tan|asin|acos|atan|log|ln|abs|floor|ceil|round|exp|pow|pi)\b/.test(s) || /[0-9][a-z(]/.test(s) || /[a-z)]\d/.test(s);
    if (!needsOp) return "";
    try {
      const v = evalMath(s);
      if (typeof v !== "number" || !isFinite(v)) return "";
      return formatNumber(v);
    } catch (e) {
      return "";
    }
  }

  function formatNumber(v) {
    return String(Math.round(v * 1e10) / 1e10);
  }

  function evalMath(src) {
    const tokens = [];
    let i = 0;
    while (i < src.length) {
      const ch = src[i];
      if (ch === " " || ch === "\t") { i++; continue; }
      if ((ch >= "0" && ch <= "9") || ch === ".") {
        let j = i, dot = false;
        while (j < src.length && ((src[j] >= "0" && src[j] <= "9") || src[j] === ".")) {
          if (src[j] === ".") { if (dot) break; dot = true; }
          j++;
        }
        const n = parseFloat(src.slice(i, j));
        if (!isFinite(n)) throw "nan";
        tokens.push({ t: "num", v: n });
        i = j;
        continue;
      }
      if (ch >= "a" && ch <= "z") {
        let j = i;
        while (j < src.length && src[j] >= "a" && src[j] <= "z") j++;
        tokens.push({ t: "id", v: src.slice(i, j) });
        i = j;
        continue;
      }
      if ("+-*/^%(),".indexOf(ch) >= 0) { tokens.push({ t: "op", v: ch }); i++; continue; }
      throw "bad";
    }
    let pos = 0;
    const peek = () => pos < tokens.length ? tokens[pos] : null;
    const nextTok = () => tokens[pos++];
    function parseExpr() {
      let v = parseTerm();
      for (;;) {
        const tk = peek();
        if (!tk || tk.t !== "op" || (tk.v !== "+" && tk.v !== "-")) return v;
        nextTok();
        const rhs = parseTerm();
        v = tk.v === "+" ? v + rhs : v - rhs;
      }
    }
    function parseTerm() {
      let v = parseFactor();
      for (;;) {
        const tk = peek();
        if (!tk || tk.t !== "op" || (tk.v !== "*" && tk.v !== "/")) return v;
        nextTok();
        const rhs = parseFactor();
        v = tk.v === "*" ? v * rhs : v / rhs;
      }
    }
    function parseFactor() {
      let v = parseUnary();
      const tk = peek();
      if (tk && tk.t === "op" && tk.v === "^") {
        nextTok();
        v = Math.pow(v, parseFactor());
      }
      for (;;) {
        const nx = peek();
        if (nx && (nx.t === "num" || nx.t === "id" || (nx.t === "op" && nx.v === "("))) v = v * parseUnary();
        else return v;
      }
    }
    function parseUnary() {
      const tk = peek();
      if (tk && tk.t === "op" && (tk.v === "+" || tk.v === "-")) {
        nextTok();
        const v = parseUnary();
        return tk.v === "-" ? -v : v;
      }
      return parsePostfix();
    }
    function parsePostfix() {
      let v = parsePrimary();
      for (;;) {
        const tk = peek();
        if (tk && tk.t === "op" && tk.v === "%") { nextTok(); v = v / 100; }
        else return v;
      }
    }
    function parsePrimary() {
      const tk = nextTok();
      if (!tk) throw "end";
      if (tk.t === "num") return tk.v;
      if (tk.t === "op" && tk.v === "(") {
        const v = parseExpr();
        const cl = nextTok();
        if (!cl || cl.t !== "op" || cl.v !== ")") throw "paren";
        return v;
      }
      if (tk.t === "id") {
        if (tk.v === "pi") return Math.PI;
        if (tk.v === "e") return Math.E;
        const open = peek();
        if (open && open.t === "op" && open.v === "(") {
          nextTok();
          const args = [];
          const first = peek();
          if (first && !(first.t === "op" && first.v === ")")) {
            args.push(parseExpr());
            while (peek() && peek().t === "op" && peek().v === ",") { nextTok(); args.push(parseExpr()); }
          }
          const cl = nextTok();
          if (!cl || cl.t !== "op" || cl.v !== ")") throw "paren";
          return applyFunc(tk.v, args);
        }
        throw "unknown";
      }
      throw "bad";
    }
    function applyFunc(name, args) {
      const one = f => { if (args.length !== 1) throw "args"; return f(args[0]); };
      switch (name) {
        case "sqrt": return one(Math.sqrt);
        case "cbrt": return one(Math.cbrt);
        case "sin": return one(Math.sin);
        case "cos": return one(Math.cos);
        case "tan": return one(Math.tan);
        case "asin": return one(Math.asin);
        case "acos": return one(Math.acos);
        case "atan": return one(Math.atan);
        case "log": return one(Math.log10);
        case "ln": return one(Math.log);
        case "abs": return one(Math.abs);
        case "floor": return one(Math.floor);
        case "ceil": return one(Math.ceil);
        case "round": return one(Math.round);
        case "exp": return one(Math.exp);
        case "pow": if (args.length !== 2) throw "args"; return Math.pow(args[0], args[1]);
        default: throw "unknown";
      }
    }
    const result = parseExpr();
    if (pos !== tokens.length) throw "trailing";
    return result;
  }

  function clipboardKindLabel(e) {
    if (!e) return "Clipboard";
    if (e.kind === "svg") return "Vector image";
    if (e.kind === "markdown") return "Markdown";
    if (e.kind === "html") return "HTML";
    if (e.kind === "image") return "Image";
    return "Text";
  }

  function launcherClipboardResults(q) {
    if (!shell || !shell.clipboardEntries) return [];
    const needle = q.replace(/^cb\s*/i, "").trim().toLowerCase();
    const pool = !needle ? shell.clipboardEntries
      : shell.clipboardEntries.filter(e =>
          String(e.preview || "").toLowerCase().includes(needle) ||
          String(e.searchText || "").toLowerCase().includes(needle) ||
          String(e.sourceName || "").toLowerCase().includes(needle));
    return pool.slice(0, 8).map(e => ({
      kind: "clip",
      title: String(e.preview || "(empty)").slice(0, 120),
      subtitle: clipboardKindLabel(e) + (e.id ? "  •  #" + e.id : ""),
      entry: e
    }));
  }

  function launcherAppResults(q) {
    const l = q.toLowerCase();
    return DesktopEntries.applications.values
      .filter(app => !q || (app.name + " " + app.keywords.join(" ")).toLowerCase().includes(l))
      .sort((a, b) => a.name.localeCompare(b.name))
      .map(app => ({ kind: "app", title: app.name, subtitle: app.genericName || "", app: app }));
  }

  function buildResults() {
    const q = search.text.trim();
    if (isClipboardMode(q)) return launcherClipboardResults(q);
    const out = [];
    const calc = tryCalculate(q);
    if (calc !== "") out.push({ kind: "calc", title: calc, subtitle: q, value: calc });
    matchingCommands(q).forEach(c => out.push({ kind: "cmd", title: c.title, subtitle: c.subtitle, cmd: c }));
    const web = detectWebEngine(q);
    if (web) {
      out.push({ kind: "web", title: web.query, subtitle: "Search " + web.engine.name, url: web.engine.url + encodeURIComponent(web.query) });
    } else {
      if (q && looksLikeUrl(q)) out.push({ kind: "web", title: q, subtitle: "Open in browser", url: normalizeUrl(q) });
      launcherAppResults(q).forEach(a => out.push(a));
      if (q && calc === "" && !looksLikeUrl(q)) {
        const short = q.length > 40 ? q.slice(0, 40) + "…" : q;
        out.push({ kind: "web", title: q, subtitle: "Search Google for \"" + short + "\"", url: "https://www.google.com/search?q=" + encodeURIComponent(q) });
      }
    }
    return out;
  }

  function launchApp(app) {
    const id = ((app && app.id) || "").trim();
    const isValidId = id.length > 0 && /^[a-zA-Z0-9_\-\.]+$/.test(id);
    if (isValidId) {
      const target = id.endsWith(".desktop") ? id : (id + ".desktop");
      Quickshell.execDetached([
        "@uwsm@",
        "app",
        "-t",
        "scope",
        "--",
        target
      ]);
    } else if (app) {
      app.execute();
    }
  }

  function runSysCommand(id) {
    if (id === "lock") Quickshell.execDetached(["secure-session-lock"]);
    else if (id === "suspend") Quickshell.execDetached(["sh", "-c", "secure-session-lock & sleep 0.5 && systemctl suspend"]);
    else if (id === "logout") Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
    else if (id === "reboot") Quickshell.execDetached(["systemctl", "reboot"]);
    else if (id === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"]);
    else if (id === "clipboard") shell.openWidget("clipboard");
    else if (id === "screenshot") shell.captureScreenshot("edit", true);
  }

  function perform(item) {
    if (!item) return;
    if (item.kind === "calc") Quickshell.execDetached(["wl-copy", item.value]);
    else if (item.kind === "web") Quickshell.execDetached(["xdg-open", item.url]);
    else if (item.kind === "clip") shell.runClipboardAction("copy", item.entry);
    else if (item.kind === "cmd") runSysCommand(item.cmd.id);
    else if (item.kind === "app") launchApp(item.app);
    shell.launcherVisible = false;
    search.text = "";
  }

  function isDangerous(item) {
    return item && item.kind === "cmd" && item.cmd && item.cmd.danger;
  }

  function badgeColor(item) {
    if (isDangerous(item)) return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.16);
    return Theme.accentSoft;
  }

  function badgeFg(item) {
    return isDangerous(item) ? Theme.danger : Theme.accent;
  }

  function badgeGlyph(item) {
    if (!item) return "";
    if (item.kind === "calc") return "=";
    if (item.kind === "web") return "󰍉";
    if (item.kind === "clip") return "󰅇";
    if (item.kind === "cmd" && item.cmd) return item.cmd.glyph;
    return "";
  }

  function kindTag(item) {
    if (!item) return "";
    if (item.kind === "calc") return "calc";
    if (item.kind === "web") return "web";
    if (item.kind === "cmd") return "cmd";
    if (item.kind === "clip") return "clip";
    return "";
  }

  function emptyHint(q) {
    if (!q) return "";
    if (isClipboardMode(q)) return "No clipboard matches — copy something first";
    return "No results for \"" + (q.length > 32 ? q.slice(0, 32) + "…" : q) + "\"";
  }

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
      TextField {
        id: search
        Layout.fillWidth: true; Layout.preferredHeight: 42
        focus: launcher.visible
        placeholderText: "Run..."
        color: Theme.text; font.family: Theme.font; font.pixelSize: 18
        placeholderTextColor: Theme.muted
        cursorDelegate: shell.themedCursor
        selectionColor: Theme.accent
        selectedTextColor: Theme.background
        selectByMouse: true
        background: Rectangle {
          radius: Theme.radiusSm
          color: Theme.surface
          border.color: parent.activeFocus ? Theme.accent : Theme.border
          border.width: 1
        }
        onTextChanged: {
          appList.currentIndex = 0;
          if (launcher.visible && launcher.isClipboardMode(text.trim()) && shell && shell.refreshClipboard)
            shell.refreshClipboard();
        }
        onAccepted: {
          const items = appList.model.values;
          if (items && appList.currentIndex >= 0 && appList.currentIndex < items.length)
            launcher.perform(items[appList.currentIndex]);
        }
        Keys.onEscapePressed: shell.launcherVisible = false
        Keys.onDownPressed: {
          if (appList.count > 0)
            appList.currentIndex = Math.min(appList.count - 1, appList.currentIndex + 1);
          appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
        }
        Keys.onUpPressed: {
          if (appList.count > 0)
            appList.currentIndex = Math.max(0, appList.currentIndex - 1);
          appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
        }
      }
      ListView {
        id: appList
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; spacing: 4
        currentIndex: 0
        highlightMoveDuration: Theme.motionFast
        model: ScriptModel {
          values: launcher.buildResults()
        }
        delegate: Rectangle {
          id: appRow
          required property var modelData
          width: ListView.view.width; height: 48; radius: 9
          color: ListView.isCurrentItem ? Theme.surfaceAlt : "transparent"
          function launch() {
            launcher.perform(appRow.modelData);
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              appList.currentIndex = index;
              appRow.launch();
            }
          }
          RowLayout {
            anchors.fill: parent; anchors.margins: 7; spacing: 12
            IconImage {
              visible: appRow.modelData.kind === "app"
              implicitSize: 30
              source: appRow.modelData.kind === "app" ? Quickshell.iconPath(appRow.modelData.app.icon, "application-x-executable") : ""
            }
            Rectangle {
              visible: appRow.modelData.kind !== "app"
              Layout.preferredWidth: 30; Layout.preferredHeight: 30
              radius: 9
              color: launcher.badgeColor(appRow.modelData)
              Text {
                anchors.centerIn: parent
                text: launcher.badgeGlyph(appRow.modelData)
                color: launcher.badgeFg(appRow.modelData)
                font.family: appRow.modelData.kind === "calc" ? Theme.fontSans : Theme.font
                font.pixelSize: appRow.modelData.kind === "calc" ? 17 : 15
                font.bold: appRow.modelData.kind === "calc"
              }
            }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 0
              Text { text: appRow.modelData.title || ""; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
              Text { visible: (appRow.modelData.subtitle || "").length > 0; text: appRow.modelData.subtitle || ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            Text {
              visible: appRow.modelData.kind !== "app"
              text: launcher.kindTag(appRow.modelData)
              color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: 10
              Layout.alignment: Qt.AlignVCenter
            }
          }
        }
        Text {
          anchors.centerIn: parent
          visible: appList.count === 0 && search.text.trim().length > 0
          text: launcher.emptyHint(search.text.trim())
          color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: 12
        }
      }
      Text {
        visible: search.text.trim().length === 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: "= calculator   •   g / gh / yt / w search   •   cb clipboard   •   lock, reboot…"
        color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: 10
      }
    }
  }
}
