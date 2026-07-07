import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Widgets
import qs

ColumnLayout {
  id: workspaceStack
  required property var shell

  spacing: 7

  Repeater {
    model: shell.workspaceEntries
    Rectangle {
      id: workspaceCell
      required property var modelData
      readonly property var clients: shell.workspaceClientList(modelData.id, 5)
      readonly property bool dragTarget: shell.workspaceDragTarget === modelData.id
      readonly property bool active: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
      readonly property bool dropActive: dragTarget && shell.workspaceDragClient !== null

      Layout.fillWidth: true
      implicitHeight: shell.workspaceCellHeight(modelData.id)
      radius: 18
      color: dragTarget ? Theme.accentSoft : (active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, clients.length > 0 ? 0.08 : 0.02))
      border.color: dragTarget || active ? Theme.accent : "transparent"
      border.width: 1
      scale: dragTarget ? 1.06 : 1

      Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on border.color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: shell.openWorkspace(workspaceCell.modelData.id)
      }

      Rectangle {
        visible: workspaceCell.dropActive
        anchors.centerIn: parent
        width: 22
        height: 22
        radius: 11
        color: Theme.accent
        opacity: 0.92
        z: 3
        Text {
          anchors.centerIn: parent
          text: "󰁅"
          color: Theme.background
          font.family: Theme.fontIcon
          font.pixelSize: 13
          font.bold: true
        }
      }

      Rectangle {
        visible: workspaceCell.dropActive
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: Math.min(parent.height - 14, 42)
        radius: 2
        color: Theme.accent
        z: 3
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
            property real pressStackY: 0
            property bool draggingWorkspaceClient: false

            width: 30
            height: 30
            scale: draggingWorkspaceClient ? 1.10 : (clientMouse.containsMouse ? 1.06 : 1)
            opacity: draggingWorkspaceClient ? 0.82 : 1

            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            Rectangle {
              anchors.centerIn: parent
              width: 30
              height: 30
              radius: 15
              color: clientMouse.containsMouse || clientBubble.draggingWorkspaceClient ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08) : "transparent"
              border.color: clientMouse.containsMouse || clientBubble.draggingWorkspaceClient ? Theme.border : "transparent"
              border.width: 1
            }
            IconImage {
              anchors.centerIn: parent
              implicitSize: shell.appIconSizeForClient(clientBubble.modelData, 24)
              source: shell.appIconSourceForClient(clientBubble.modelData)
            }
            MouseArea {
              id: clientMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: pressed || clientBubble.draggingWorkspaceClient ? Qt.ClosedHandCursor : Qt.PointingHandCursor
              onPressed: mouse => {
                clientBubble.pressStackY = mapToItem(workspaceStack, mouse.x, mouse.y).y;
                clientBubble.draggingWorkspaceClient = false;
                shell.clearWorkspaceInteraction();
              }
              onPositionChanged: mouse => {
                if (!pressed) return;
                const point = mapToItem(workspaceStack, mouse.x, mouse.y);
                if (!clientBubble.draggingWorkspaceClient && Math.abs(point.y - clientBubble.pressStackY) < 8) return;
                clientBubble.draggingWorkspaceClient = true;
                shell.workspaceDragClient = clientBubble.modelData;
                shell.workspaceDragTarget = shell.workspaceIdAtY(point.y);
              }
              onReleased: mouse => {
                const point = mapToItem(workspaceStack, mouse.x, mouse.y);
                const target = shell.workspaceIdAtY(point.y);
                if (clientBubble.draggingWorkspaceClient) {
                  if (target !== 0)
                    shell.moveWorkspaceClient(clientBubble.modelData, target);
                  else
                    shell.clearWorkspaceInteraction();
                } else {
                  shell.clearWorkspaceInteraction();
                  shell.openWorkspace(workspaceCell.modelData.id);
                }
                clientBubble.draggingWorkspaceClient = false;
              }
              onCanceled: {
                clientBubble.draggingWorkspaceClient = false;
                shell.clearWorkspaceInteraction();
              }
            }
          }
        }

        Rectangle {
          visible: (shell.workspaceClientsById[String(workspaceCell.modelData.id)] || []).length > workspaceCell.clients.length
          width: 28
          height: 20
          radius: 10
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
          border.color: Theme.border
          border.width: 1
          Text {
            anchors.centerIn: parent
            text: "+" + ((shell.workspaceClientsById[String(workspaceCell.modelData.id)] || []).length - workspaceCell.clients.length)
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
