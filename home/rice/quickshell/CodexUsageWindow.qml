import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs

PanelWindow {
  required property var shell

  visible: shell.codexUsageVisible
  focusable: true
  color: "transparent"
  implicitWidth: 380
  implicitHeight: 310
  anchors { bottom: true; right: true }
  margins { bottom: 72; right: 54 }
  exclusionMode: ExclusionMode.Ignore

  function usageUsed(key) {
    const value = shell.codexUsageValue(key);
    return value === null ? null : Math.max(0, Math.min(100, Math.round(value)));
  }

  function usageRemaining(key) {
    const used = usageUsed(key);
    return used === null ? null : Math.max(0, 100 - used);
  }

  function windowLabel(key) {
    const value = shell.codexUsageValue(key);
    if (!Number.isFinite(value)) return "window --";
    if (value >= 1440) return Math.round(value / 1440) + "d window";
    if (value >= 60) return Math.round(value / 60) + "h window";
    return Math.round(value) + "m window";
  }

  MouseArea {
    anchors.fill: parent
    onClicked: shell.codexUsageVisible = false
  }

  Rectangle {
    width: parent.width
    height: parent.height
    focus: shell.codexUsageVisible
    radius: Theme.radiusLg
    color: Theme.panel
    border.color: Theme.border
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Theme.padMd
      spacing: Theme.gapMd

      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "Codex usage"
          color: Theme.text
          font.family: Theme.fontSans
          font.bold: true
          font.pixelSize: 17
          Layout.fillWidth: true
        }
        Text {
          text: shell.codexUsage ? (shell.codexUsage.planType || "unknown") : "--"
          color: Theme.accent
          font.family: Theme.fontSans
          font.bold: true
          font.pixelSize: 12
        }
        Text {
          text: "×"
          color: Theme.muted
          font.pixelSize: 20
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: shell.codexUsageVisible = false
          }
        }
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

      ColumnLayout {
        visible: !!shell.codexUsage
        Layout.fillWidth: true
        spacing: Theme.gapMd

        Repeater {
          model: [
            {
              label: "Primary",
              usedKey: "primaryUsedPercent",
              resetKey: "primaryResetsAt",
              windowKey: "primaryWindowMinutes"
            },
            {
              label: "Secondary",
              usedKey: "secondaryUsedPercent",
              resetKey: "secondaryResetsAt",
              windowKey: "secondaryWindowMinutes"
            }
          ]

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 76
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 11
              spacing: 7

              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: parent.parent.parent.modelData.label
                  color: Theme.text
                  font.family: Theme.fontSans
                  font.bold: true
                  font.pixelSize: 13
                  Layout.fillWidth: true
                }
                Text {
                  text: {
                    const remaining = usageRemaining(parent.parent.parent.modelData.usedKey);
                    return remaining === null ? "-- left" : remaining + "% left";
                  }
                  color: Theme.accent
                  font.family: Theme.fontSans
                  font.bold: true
                  font.pixelSize: 12
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 9
                radius: 5
                color: Theme.background
                clip: true
                Rectangle {
                  height: parent.height
                  radius: parent.radius
                  color: {
                    const used = usageUsed(parent.parent.parent.modelData.usedKey);
                    if (used === null) return Theme.muted;
                    if (used >= 90) return Theme.danger;
                    if (used >= 75) return Theme.warning;
                    return Theme.accent;
                  }
                  width: {
                    const used = usageUsed(parent.parent.parent.modelData.usedKey);
                    return parent.width * (used === null ? 0 : used / 100);
                  }
                }
              }

              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: {
                    const used = usageUsed(parent.parent.parent.modelData.usedKey);
                    return used === null ? "used --" : "used " + used + "%";
                  }
                  color: shell.secondaryText
                  font.family: Theme.fontSans
                  font.pixelSize: 11
                  Layout.fillWidth: true
                }
                Text {
                  text: windowLabel(parent.parent.parent.modelData.windowKey) + " · reset " + shell.codexUsageResetLabel(shell.codexUsageValue(parent.parent.parent.modelData.resetKey))
                  color: shell.secondaryText
                  font.family: Theme.fontSans
                  font.pixelSize: 11
                }
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 58
          radius: Theme.radiusMd
          color: Theme.surfaceAlt
          border.color: Theme.border
          border.width: 1

          GridLayout {
            anchors.fill: parent
            anchors.margins: 11
            columns: 2
            columnSpacing: Theme.gapMd
            rowSpacing: 4
            Text {
              text: "Credits"
              color: shell.secondaryText
              font.family: Theme.fontSans
              font.pixelSize: 11
            }
            Text {
              Layout.fillWidth: true
              text: shell.codexUsage && shell.codexUsage.credits !== null && shell.codexUsage.credits !== undefined
                ? String(shell.codexUsage.credits)
                : "--"
              color: Theme.text
              font.family: Theme.fontSans
              font.pixelSize: 12
              font.bold: true
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }
            Text {
              text: "Generated"
              color: shell.secondaryText
              font.family: Theme.fontSans
              font.pixelSize: 11
            }
            Text {
              Layout.fillWidth: true
              text: shell.codexUsage && shell.codexUsage.generatedAt
                ? Qt.formatDateTime(new Date(shell.codexUsage.generatedAt * 1000), "HH:mm")
                : "--"
              color: Theme.text
              font.family: Theme.fontSans
              font.pixelSize: 12
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
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

    Keys.onEscapePressed: shell.codexUsageVisible = false
  }
}
