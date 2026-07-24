pragma Singleton

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

Item {
  id: state

  visible: false
  width: 0
  height: 0

  property var entries: []
  property var clientsById: ({})
  property bool refreshQueued: false

  function eventChangesWorkspaceState(name) {
    return name.includes("workspace")
      || name.includes("window")
      || name === "focusedmon"
      || name === "urgent";
  }

  function scheduleRefresh() {
    state.refreshQueued = true;
    refreshDebounce.restart();
  }

  function windowAddress(client) {
    const address = String(client.address || "");
    if (address.length === 0 || address.toLowerCase().indexOf("0x") === 0)
      return address;
    return "0x" + address;
  }

  function startRefresh() {
    if (workspaceQuery.running)
      return;
    state.refreshQueued = false;
    workspaceQuery.running = true;
  }

  function refresh(snapshot) {
    const workspaces = snapshot.workspaces || [];
    const toplevels = snapshot.clients || [];
    const clients = {};

    for (const toplevel of toplevels) {
      if (!toplevel || !toplevel.workspace || Number(toplevel.workspace.id) === 0)
        continue;

      const workspaceId = Number(toplevel.workspace.id);
      const key = String(workspaceId);
      if (!clients[key]) clients[key] = [];
      clients[key].push({
        address: state.windowAddress(toplevel),
        className: toplevel["class"] || toplevel.initialClass || "",
        title: toplevel.title || toplevel.initialTitle || "",
        urgent: Boolean(toplevel.urgent),
        workspaceId: workspaceId,
        workspaceName: toplevel.workspace.name || String(workspaceId)
      });
    }

    const byId = {};
    let maxId = 0;
    for (const workspace of workspaces) {
      if (!workspace || Number(workspace.id) === 0)
        continue;
      const workspaceId = Number(workspace.id);
      const key = String(workspaceId);
      const workspaceClients = clients[key] || [];
      const isFocused = Hyprland.focusedWorkspace
        && Hyprland.focusedWorkspace.id === workspaceId;
      byId[key] = {
        id: workspaceId,
        name: workspace.name || key,
        windows: workspaceClients.length,
        active: isFocused,
        focused: isFocused,
        urgent: workspaceClients.some(client => client.urgent)
      };
      if (workspaceId > 0)
        maxId = Math.max(maxId, workspaceId);
    }

    for (const key of Object.keys(clients)) {
      if (byId[key])
        continue;
      const workspaceClients = clients[key];
      const workspaceId = Number(key);
      const isFocused = Hyprland.focusedWorkspace
        && Hyprland.focusedWorkspace.id === workspaceId;
      byId[key] = {
        id: workspaceId,
        name: workspaceClients[0].workspaceName || key,
        windows: workspaceClients.length,
        active: isFocused,
        focused: isFocused,
        urgent: workspaceClients.some(client => client.urgent)
      };
      if (workspaceId > 0)
        maxId = Math.max(maxId, workspaceId);
    }

    const nextEntries = [];
    for (let id = 1; id <= maxId; id++) {
      nextEntries.push(byId[String(id)] || {
        id: id,
        name: String(id),
        windows: 0,
        active: false,
        focused: false,
        urgent: false
      });
    }

    const specialEntries = Object.values(byId)
      .filter(workspace => workspace.id < 0)
      .sort((a, b) => String(a.name).localeCompare(String(b.name)));
    for (const workspace of specialEntries)
      nextEntries.push(workspace);

    state.clientsById = clients;
    state.entries = nextEntries;
  }

  Process {
    id: workspaceQuery

    command: ["@workspaceStateQuery@"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          state.refresh(JSON.parse(text));
        } catch (error) {
          console.warn("Could not refresh Hyprland workspace state:", error);
        }
      }
    }
    onExited: {
      if (state.refreshQueued)
        refreshDebounce.restart();
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event && state.eventChangesWorkspaceState(event.name))
        state.scheduleRefresh();
    }
  }

  Timer {
    id: refreshDebounce

    interval: 60
    onTriggered: state.startRefresh()
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: state.scheduleRefresh()
  }

  Component.onCompleted: state.scheduleRefresh()
}
