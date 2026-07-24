pragma Singleton

import QtQuick
import Quickshell.Hyprland

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
    if (state.refreshQueued) return;
    state.refreshQueued = true;
    Qt.callLater(() => {
      state.refreshQueued = false;
      state.refresh();
    });
  }

  function refresh() {
    const workspaces = Hyprland.workspaces && Hyprland.workspaces.values
      ? Hyprland.workspaces.values
      : [];
    const toplevels = Hyprland.toplevels && Hyprland.toplevels.values
      ? Hyprland.toplevels.values
      : [];
    const clients = {};

    for (const toplevel of toplevels) {
      if (!toplevel || !toplevel.workspace || toplevel.workspace.id === 0)
        continue;

      const workspaceId = toplevel.workspace.id;
      const key = String(workspaceId);
      const ipc = toplevel.lastIpcObject || {};
      if (!clients[key]) clients[key] = [];
      clients[key].push({
        address: toplevel.address || "",
        className: ipc["class"] || ipc.initialClass || "",
        title: toplevel.title || ipc.title || ipc.initialTitle || "",
        workspaceId: workspaceId,
        workspaceName: toplevel.workspace.name || String(workspaceId)
      });
    }

    const byId = {};
    let maxId = 0;
    for (const workspace of workspaces) {
      if (!workspace || workspace.id === 0)
        continue;
      const key = String(workspace.id);
      byId[key] = {
        id: workspace.id,
        name: workspace.name || key,
        windows: (clients[key] || []).length,
        active: workspace.active,
        focused: workspace.focused,
        urgent: workspace.urgent
      };
      if (workspace.id > 0)
        maxId = Math.max(maxId, workspace.id);
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

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event && state.eventChangesWorkspaceState(event.name))
        state.scheduleRefresh();
    }
  }

  Timer {
    id: initialRefresh

    interval: 250
    onTriggered: state.refresh()
  }

  Component.onCompleted: {
    Hyprland.refreshWorkspaces();
    Hyprland.refreshToplevels();
    state.scheduleRefresh();
    initialRefresh.start();
  }
}
