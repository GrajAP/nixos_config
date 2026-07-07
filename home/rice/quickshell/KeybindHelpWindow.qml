import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs

PanelWindow {
  required property var shell
    visible: shell.keybindHelpVisible
    focusable: true
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      onClicked: mouse => {
        const point = mapToItem(keybindHelpPanel, mouse.x, mouse.y);
        if (point.x < 0 || point.y < 0 || point.x > keybindHelpPanel.width || point.y > keybindHelpPanel.height)
          shell.keybindHelpVisible = false;
      }
    }

    Rectangle {
      id: keybindHelpPanel
      width: Math.min(1180, parent.width - 44)
      height: Math.min(760, parent.height - 44)
      focus: shell.keybindHelpVisible
      anchors.centerIn: parent
      radius: Theme.radiusLg
      color: Theme.panel
      border.color: Theme.border
      border.width: 1
      clip: true

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.padLg
        spacing: Theme.gapMd

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Keybinds"
            color: Theme.text
            font.family: Theme.fontSans
            font.bold: true
            font.pixelSize: 20
            Layout.fillWidth: true
          }
          Text {
            text: "Mod + /"
            color: shell.secondaryText
            font.family: Theme.fontSans
            font.pixelSize: 12
          }
          Text {
            text: "×"
            color: Theme.muted
            font.pixelSize: 22
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shell.keybindHelpVisible = false }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Theme.gapLg

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: 720
            spacing: 8

            Repeater {
              model: shell.keyboardRows
              RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                  model: parent.modelData
                  Rectangle {
                    required property string modelData
                    readonly property var matches: shell.keybindsForKey(modelData)
                    Layout.fillWidth: true
                    Layout.preferredWidth: 52 * shell.keyWidthUnits(modelData)
                    Layout.preferredHeight: 58
                    radius: Theme.radiusSm
                    color: matches.length > 0 ? Theme.accentSoft : Theme.surface
                    border.color: matches.length > 0 ? Theme.accent : Theme.border
                    border.width: 1
                    clip: true

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 7
                      spacing: 2
                      Text {
                        Layout.fillWidth: true
                        text: parent.parent.modelData
                        color: parent.parent.matches.length > 0 ? Theme.text : shell.secondaryText
                        font.family: Theme.fontSans
                        font.bold: true
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                      }
                      Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: shell.keybindKeyLabel(parent.parent.modelData)
                        color: shell.secondaryText
                        font.family: Theme.fontSans
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 42
              radius: Theme.radiusSm
              color: Theme.surfaceAlt
              border.color: Theme.border
              border.width: 1
              Text {
                anchors.centerIn: parent
                width: parent.width - 24
                text: "Highlighted keys have configured Hyprland or Quickshell binds. Full list is on the right."
                color: shell.secondaryText
                font.family: Theme.fontSans
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }
            }
          }

          ScrollView {
            id: keybindListScroll
            Layout.preferredWidth: 390
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
              width: keybindListScroll.availableWidth
              spacing: 12

              Repeater {
                model: shell.keybindHelpCategories()
                ColumnLayout {
                  required property string modelData
                  width: parent.width
                  spacing: 6
                  Text {
                    Layout.fillWidth: true
                    text: parent.modelData
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.bold: true
                    font.pixelSize: 12
                  }
                  Repeater {
                    model: shell.keybindsInCategory(parent.modelData)
                    Rectangle {
                      required property var modelData
                      Layout.fillWidth: true
                      implicitHeight: 42
                      radius: Theme.radiusSm
                      color: Theme.surface
                      border.color: Theme.border
                      border.width: 1
                      RowLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 10
                        Text {
                          Layout.preferredWidth: 118
                          text: parent.parent.modelData.combo
                          color: Theme.accent
                          font.family: Theme.fontSans
                          font.pixelSize: 11
                          font.bold: true
                          elide: Text.ElideRight
                        }
                        Text {
                          Layout.fillWidth: true
                          text: parent.parent.modelData.description
                          color: Theme.text
                          font.family: Theme.fontSans
                          font.pixelSize: 11
                          elide: Text.ElideRight
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      Keys.onEscapePressed: shell.keybindHelpVisible = false
    }
  }
