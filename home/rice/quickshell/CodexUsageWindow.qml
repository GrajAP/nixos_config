import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs

ColumnLayout {
  required property var shell

  Layout.fillWidth: true
  Layout.fillHeight: true
  spacing: Theme.gapMd

  function usageValue(key) {
    const value = shell.codexUsageValue(key);
    return value === null ? null : Math.max(0, Math.min(100, Math.round(value)));
  }

  function windowLabel(key) {
    return shell.codexUsageWindowLabel(shell.codexUsageValue(key)) + " window";
  }

  Text {
    Layout.fillWidth: true
    visible: shell.codexUsageError.length > 0 || !shell.codexUsage
    text: shell.codexUsageError.length > 0 ? shell.codexUsageError : "No usage data yet"
    color: shell.codexUsageError.length > 0 ? Theme.danger : Theme.muted
    font.family: Theme.fontSans
    font.pixelSize: 12
    wrapMode: Text.Wrap
  }

  Repeater {
    model: shell.codexUsage ? [
      {
        label: "Codex primary",
        usedKey: "codexPrimaryUsedPercent",
        resetKey: "codexPrimaryResetsAt",
        windowKey: "codexPrimaryWindowMinutes"
      },
      {
        label: "Codex secondary",
        usedKey: "codexSecondaryUsedPercent",
        resetKey: "codexSecondaryResetsAt",
        windowKey: "codexSecondaryWindowMinutes"
      },
      {
        label: "GPT-5.3-Codex-Spark",
        usedKey: "sparkPrimaryUsedPercent",
        resetKey: "sparkPrimaryResetsAt",
        windowKey: "sparkPrimaryWindowMinutes"
      },
      {
        label: "Spark secondary",
        usedKey: "sparkSecondaryUsedPercent",
        resetKey: "sparkSecondaryResetsAt",
        windowKey: "sparkSecondaryWindowMinutes"
      }
    ] : []

    Rectangle {
      required property var modelData
      Layout.fillWidth: true
      implicitHeight: 68
      radius: Theme.radiusMd
      color: Theme.surface
      border.color: Theme.border
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 9
        spacing: 5

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: parent.parent.parent.modelData.label
            color: Theme.text
            font.family: Theme.fontSans
            font.bold: true
            font.pixelSize: 12
            Layout.fillWidth: true
            elide: Text.ElideRight
          }
          Text {
            text: {
              const used = usageValue(parent.parent.parent.modelData.usedKey);
              return used === null ? "used --" : used + "% used";
            }
            color: Theme.accent
            font.family: Theme.fontSans
            font.bold: true
            font.pixelSize: 11
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 8
          radius: 5
          color: Theme.background
          clip: true
          Rectangle {
            height: parent.height
            radius: parent.radius
            color: {
              const used = usageValue(parent.parent.parent.modelData.usedKey);
              if (used === null) return Theme.muted;
              if (used >= 90) return Theme.danger;
              if (used >= 75) return Theme.warning;
              return Theme.accent;
            }
            width: {
              const used = usageValue(parent.parent.parent.modelData.usedKey);
              return parent.width * (used === null ? 0 : used / 100);
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: {
              const used = usageValue(parent.parent.parent.modelData.usedKey);
              return used === null ? "used --" : "used " + used + "%";
            }
            color: shell.secondaryText
            font.family: Theme.fontSans
            font.pixelSize: 10
            Layout.fillWidth: true
          }
          Text {
            Layout.preferredWidth: 220
            text: windowLabel(parent.parent.parent.modelData.windowKey) + " · reset " + shell.codexUsageResetLabel(shell.codexUsageValue(parent.parent.parent.modelData.resetKey))
            color: shell.secondaryText
            font.family: Theme.fontSans
            font.pixelSize: 10
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  Item { Layout.fillHeight: true }

  RowLayout {
    Layout.fillWidth: true
    Text {
      Layout.fillWidth: true
      text: shell.codexUsage && shell.codexUsage.generatedAt
        ? "Updated " + Qt.formatDateTime(new Date(shell.codexUsage.generatedAt * 1000), "HH:mm")
        : ""
      color: shell.secondaryText
      font.family: Theme.fontSans
      font.pixelSize: 11
      elide: Text.ElideRight
    }
    Rectangle {
      Layout.preferredWidth: 92
      Layout.preferredHeight: 30
      radius: Theme.radiusSm
      color: Theme.surface
      Text {
        anchors.centerIn: parent
        text: "Refresh"
        color: Theme.accent
        font.family: Theme.fontSans
        font.bold: true
        font.pixelSize: 12
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: shell.refreshCodexUsage()
      }
    }
  }
}
