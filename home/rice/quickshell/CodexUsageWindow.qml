import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs

ColumnLayout {
  required property var shell
  // OpenAI currently does not enforce the 5-hour windows. Keep their cards
  // available so they can be restored by changing this flag to true.
  readonly property bool showFiveHourLimits: false

  Layout.fillWidth: true
  Layout.fillHeight: true
  spacing: Theme.gapMd

  function usageValue(key) {
    const value = shell.codexUsageValue(key);
    return value === null ? null : Math.max(0, Math.min(100, Math.round(value)));
  }
  function displayValue(metric, value) {
    if (value === null) return null;
    return value;
  }
  function percentValue(key) {
    const value = shell.codexUsageValue(key);
    return value === null ? null : Math.max(0, Math.min(100, Math.round(value)));
  }
  function metricLabel(usedKey, availableKey) {
    const used = percentValue(usedKey);
    const available = percentValue(availableKey);
    const usedText = used === null ? "--" : used + "%";
    const availableText = available === null ? "--" : available + "%";
    return usedText + " used · " + availableText + " available";
  }
  function metricColor(metric, value) {
    const display = displayValue(metric, value);
    if (display === null) return Theme.muted;
    if (display >= 90) return Theme.danger;
    if (display >= 75) return Theme.warning;
    return Theme.accent;
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
        fiveHourLimit: true,
        metric: "used",
        usedKey: "codexPrimaryUsedPercent",
        availableKey: "codexPrimaryAvailablePercent",
        resetKey: "codexPrimaryResetsAt",
        windowKey: "codexPrimaryWindowMinutes"
      },
      {
        label: "Codex secondary",
        fiveHourLimit: false,
        metric: "used",
        usedKey: "codexSecondaryUsedPercent",
        availableKey: "codexSecondaryAvailablePercent",
        resetKey: "codexSecondaryResetsAt",
        windowKey: "codexSecondaryWindowMinutes"
      },
      {
        label: "GPT-5.3-Codex-Spark",
        fiveHourLimit: true,
        metric: "used",
        usedKey: "sparkPrimaryUsedPercent",
        availableKey: "sparkPrimaryAvailablePercent",
        resetKey: "sparkPrimaryResetsAt",
        windowKey: "sparkPrimaryWindowMinutes"
      },
      {
        label: "Spark secondary",
        fiveHourLimit: false,
        metric: "used",
        usedKey: "sparkSecondaryUsedPercent",
        availableKey: "sparkSecondaryAvailablePercent",
        resetKey: "sparkSecondaryResetsAt",
        windowKey: "sparkSecondaryWindowMinutes"
      }
    ].filter(limit => showFiveHourLimits || !limit.fiveHourLimit) : []

    Rectangle {
      id: usageCard
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
            text: usageCard.modelData.label
            color: Theme.text
            font.family: Theme.fontSans
            font.bold: true
            font.pixelSize: 12
            Layout.fillWidth: true
            elide: Text.ElideRight
          }
          Text {
            text: {
              const value = usageValue(usageCard.modelData.usedKey);
              if (value === null) return "used --";
              return value + "% used";
            }
            color: metricColor(usageCard.modelData.metric, usageValue(usageCard.modelData.usedKey))
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
              return metricColor(usageCard.modelData.metric, usageValue(usageCard.modelData.usedKey));
            }
            width: {
              const value = usageValue(usageCard.modelData.usedKey);
              const display = displayValue(usageCard.modelData.metric, value);
              return parent.width * (display === null ? 0 : display / 100);
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: {
              return metricLabel(usageCard.modelData.usedKey, usageCard.modelData.availableKey);
            }
            color: shell.secondaryText
            font.family: Theme.fontSans
            font.pixelSize: 10
            Layout.fillWidth: true
          }
          Text {
            Layout.preferredWidth: 220
            text: windowLabel(usageCard.modelData.windowKey) + " · reset " + shell.codexUsageResetLabel(shell.codexUsageValue(usageCard.modelData.resetKey))
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
