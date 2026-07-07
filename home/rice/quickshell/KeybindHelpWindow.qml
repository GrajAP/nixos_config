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
  margins.right: 44
  exclusionMode: ExclusionMode.Ignore

  MouseArea {
    anchors.fill: parent
    enabled: shell.keybindHelpVisible
    onClicked: mouse => {
      const point = mapToItem(keybindHelpPanel, mouse.x, mouse.y);
      if (point.x < 0 || point.y < 0 || point.x > keybindHelpPanel.width || point.y > keybindHelpPanel.height)
        shell.keybindHelpVisible = false;
    }
  }

  Rectangle {
    id: keybindHelpPanel
    width: parent.width
    height: parent.height
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: 0
    anchors.bottomMargin: 0
    focus: shell.keybindHelpVisible
    radius: 0
    color: shell.translucentPanel
    border.color: "transparent"
    border.width: 0
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 28
      spacing: Theme.gapMd

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gapMd

        Text {
          text: "Keybinds"
          color: Theme.text
          font.family: Theme.fontSans
          font.bold: true
          font.pixelSize: 22
          Layout.preferredWidth: 150
        }

        TextField {
          id: keybindSearch
          Layout.fillWidth: true
          Layout.preferredHeight: 38
          focus: shell.keybindHelpVisible
          text: shell.keybindHelpFilter
          placeholderText: "Search binds"
          color: Theme.text
          placeholderTextColor: Theme.muted
          font.family: Theme.fontSans
          font.pixelSize: 13
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
          onTextChanged: shell.keybindHelpFilter = text
          Keys.onEscapePressed: {
            if (shell.keybindHelpFilter.length > 0) shell.keybindHelpFilter = "";
            else shell.keybindHelpVisible = false;
          }
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
          font.pixelSize: 24
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: shell.keybindHelpVisible = false
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Theme.gapLg

        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 900
          spacing: Theme.gapSm

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 604
            radius: Theme.radiusMd
            color: "transparent"
            border.color: Theme.border
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.margins: 10
              spacing: Theme.gapMd

            ColumnLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 760
              spacing: 6

              Repeater {
                model: shell.keyboardMainRows
                RowLayout {
                  required property var modelData
                  Layout.fillWidth: true
                  spacing: 6

                  Repeater {
                    model: parent.modelData
                    Rectangle {
                      required property string modelData
                      readonly property var matches: shell.keybindsForKey(modelData)
                      readonly property bool selected: shell.keybindHelpSelectedKey === modelData
                      readonly property bool isSpacer: modelData.length === 0
                      Layout.fillWidth: true
                      Layout.preferredWidth: 54 * shell.keyWidthUnits(modelData)
                      Layout.preferredHeight: 82
                      radius: Theme.radiusSm
                      color: selected ? Theme.accent : (matches.length > 0 ? Theme.accentSoft : Theme.surface)
                      border.color: selected ? Theme.accent : (matches.length > 0 ? Theme.accent : Theme.border)
                      border.width: 1
                      clip: true
                      opacity: isSpacer ? 0 : 1

                      ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 2
                        Text {
                          Layout.fillWidth: true
                          text: parent.parent.modelData
                          color: parent.parent.selected ? Theme.background : (parent.parent.matches.length > 0 ? Theme.text : shell.secondaryText)
                          font.family: Theme.fontSans
                          font.bold: true
                          font.pixelSize: 14
                          horizontalAlignment: Text.AlignHCenter
                          elide: Text.ElideRight
                        }
                        Text {
                          Layout.fillWidth: true
                          Layout.fillHeight: true
                          text: shell.keybindKeyLabel(parent.parent.modelData)
                          color: parent.parent.selected ? Theme.background : shell.secondaryText
                          font.family: Theme.fontSans
                          font.pixelSize: 10
                          horizontalAlignment: Text.AlignHCenter
                          verticalAlignment: Text.AlignVCenter
                          wrapMode: Text.Wrap
                          maximumLineCount: 2
                          elide: Text.ElideRight
                        }
                      }

                      MouseArea {
                        anchors.fill: parent
                        enabled: !parent.isSpacer
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.keybindHelpSelectedKey = parent.modelData
                      }
                    }
                  }
                }
              }
            }

            ColumnLayout {
              Layout.preferredWidth: 168
              Layout.fillHeight: true
              Layout.alignment: Qt.AlignTop
              spacing: 18

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                  model: shell.keyboardNavRows
                  RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                      model: parent.modelData
                      Rectangle {
                        required property string modelData
                        readonly property var matches: shell.keybindsForKey(modelData)
                        readonly property bool selected: shell.keybindHelpSelectedKey === modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 62
                        radius: Theme.radiusSm
                        color: selected ? Theme.accent : (matches.length > 0 ? Theme.accentSoft : Theme.surface)
                        border.color: selected ? Theme.accent : (matches.length > 0 ? Theme.accent : Theme.border)
                        border.width: 1
                        clip: true

                        ColumnLayout {
                          anchors.fill: parent
                          anchors.margins: 6
                          spacing: 2
                          Text {
                            Layout.fillWidth: true
                            text: parent.parent.modelData
                            color: parent.parent.selected ? Theme.background : (parent.parent.matches.length > 0 ? Theme.text : shell.secondaryText)
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
                            color: parent.parent.selected ? Theme.background : shell.secondaryText
                            font.family: Theme.fontSans
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                          }
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: shell.keybindHelpSelectedKey = parent.modelData
                        }
                      }
                    }
                  }
                }
              }

              Item { Layout.fillHeight: true }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                  model: shell.keyboardArrowRows
                  RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                      model: parent.modelData
                      Rectangle {
                        required property string modelData
                        readonly property var matches: shell.keybindsForKey(modelData)
                        readonly property bool selected: shell.keybindHelpSelectedKey === modelData
                        readonly property bool isSpacer: modelData.length === 0
                        Layout.fillWidth: true
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 62
                        radius: Theme.radiusSm
                        color: selected ? Theme.accent : (matches.length > 0 ? Theme.accentSoft : Theme.surface)
                        border.color: selected ? Theme.accent : (matches.length > 0 ? Theme.accent : Theme.border)
                        border.width: 1
                        clip: true
                        opacity: isSpacer ? 0 : 1

                        ColumnLayout {
                          anchors.fill: parent
                          anchors.margins: 6
                          spacing: 2
                          Text {
                            Layout.fillWidth: true
                            text: parent.parent.modelData
                            color: parent.parent.selected ? Theme.background : (parent.parent.matches.length > 0 ? Theme.text : shell.secondaryText)
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
                            color: parent.parent.selected ? Theme.background : shell.secondaryText
                            font.family: Theme.fontSans
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                          }
                        }

                        MouseArea {
                          anchors.fill: parent
                          enabled: !parent.isSpacer
                          cursorShape: Qt.PointingHandCursor
                          onClicked: shell.keybindHelpSelectedKey = parent.modelData
                        }
                      }
                    }
                  }
                }
              }
            }

            Rectangle {
              Layout.preferredWidth: 138
              Layout.preferredHeight: 250
              Layout.alignment: Qt.AlignVCenter
              radius: 42
              color: Theme.surface
              border.color: Theme.border
              border.width: 1
              clip: true

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                width: 8
                height: 32
                radius: 4
                color: shell.keybindsForKey("Wheel Up").length > 0 || shell.keybindsForKey("Wheel Down").length > 0 ? Theme.accentSoft : Theme.surfaceAlt
                border.color: Theme.border
                border.width: 1
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: shell.keybindHelpSelectedKey = "Wheel Up"
                  onWheel: wheel => shell.keybindHelpSelectedKey = wheel.angleDelta.y > 0 ? "Wheel Up" : "Wheel Down"
                }
              }

              RowLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 12
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Repeater {
                  model: ["Mouse Left", "Mouse Right"]
                  Rectangle {
                    required property string modelData
                    readonly property var matches: shell.keybindsForKey(modelData)
                    readonly property bool selected: shell.keybindHelpSelectedKey === modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84
                    radius: 28
                    color: selected ? Theme.accent : (matches.length > 0 ? Theme.accentSoft : Theme.surfaceAlt)
                    border.color: selected ? Theme.accent : (matches.length > 0 ? Theme.accent : Theme.border)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      width: parent.width - 12
                      text: modelData === "Mouse Left" ? "Left" : "Right"
                      color: parent.selected ? Theme.background : Theme.text
                      font.family: Theme.fontSans
                      font.pixelSize: 12
                      font.bold: true
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: shell.keybindHelpSelectedKey = parent.modelData
                    }
                  }
                }
              }

              ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                spacing: 8

                Repeater {
                  model: ["Wheel Up", "Wheel Down"]
                  Rectangle {
                    required property string modelData
                    readonly property var matches: shell.keybindsForKey(modelData)
                    readonly property bool selected: shell.keybindHelpSelectedKey === modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    radius: Theme.radiusSm
                    color: selected ? Theme.accent : (matches.length > 0 ? Theme.accentSoft : Theme.surfaceAlt)
                    border.color: selected ? Theme.accent : (matches.length > 0 ? Theme.accent : Theme.border)
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: modelData === "Wheel Up" ? "Wheel up" : "Wheel down"
                      color: parent.selected ? Theme.background : Theme.text
                      font.family: Theme.fontSans
                      font.pixelSize: 11
                      font.bold: true
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: shell.keybindHelpSelectedKey = parent.modelData
                    }
                  }
                }
              }
            }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 560
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            clip: true

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Theme.padMd
              spacing: Theme.gapSm

              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: shell.keybindHelpSelectedKey.length > 0 ? "Binds for " + shell.keybindHelpSelectedKey : "No key selected"
                  color: Theme.text
                  font.family: Theme.fontSans
                  font.bold: true
                  font.pixelSize: 16
                  Layout.fillWidth: true
                }
                Text {
                  visible: shell.keybindHelpSelectedKey.length > 0
                  text: "Clear"
                  color: Theme.accent
                  font.family: Theme.fontSans
                  font.pixelSize: 13
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: shell.keybindHelpSelectedKey = ""
                  }
                }
              }

              ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 7
                model: shell.selectedKeybinds()
                delegate: Rectangle {
                  required property var modelData
                  width: ListView.view.width
                  height: 42
                  radius: Theme.radiusSm
                  color: Theme.background
                  border.color: Theme.border
                  border.width: 1
                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 10
                    Text {
                      Layout.preferredWidth: 130
                      text: parent.parent.modelData.combo
                      color: Theme.accent
                      font.family: Theme.fontSans
                      font.pixelSize: 12
                      font.bold: true
                      elide: Text.ElideRight
                    }
                    Text {
                      Layout.fillWidth: true
                      text: parent.parent.modelData.description
                      color: Theme.text
                      font.family: Theme.fontSans
                      font.pixelSize: 12
                      elide: Text.ElideRight
                    }
                  }
                }
                Text {
                  anchors.centerIn: parent
                  visible: parent.count === 0
                  text: shell.keybindHelpSelectedKey.length > 0 ? "No binds for this key" : "Select a key above"
                  color: Theme.muted
                  font.family: Theme.fontSans
                  font.pixelSize: 13
                }
              }
            }
          }
        }

        ScrollView {
          id: keybindListScroll
          Layout.preferredWidth: 430
          Layout.fillHeight: true
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          ColumnLayout {
            width: keybindListScroll.availableWidth
            spacing: Theme.gapMd

            Repeater {
              model: shell.keybindHelpFilteredCategories()
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
                  model: shell.filteredKeybindsInCategory(parent.modelData)
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
                        Layout.preferredWidth: 126
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

            Text {
              Layout.fillWidth: true
              visible: shell.filteredKeybindHelpEntries().length === 0
              text: "No matching binds"
              color: Theme.muted
              font.family: Theme.fontSans
              font.pixelSize: 12
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }
      }
    }

    Keys.onEscapePressed: {
      if (shell.keybindHelpFilter.length > 0) shell.keybindHelpFilter = "";
      else if (shell.keybindHelpSelectedKey.length > 0) shell.keybindHelpSelectedKey = "";
      else shell.keybindHelpVisible = false;
    }
  }
}
