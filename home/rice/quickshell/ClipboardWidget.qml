import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import qs

ColumnLayout {
  id: clipboardWidget

  required property var shell
  readonly property var entries: shell.filteredClipboardEntries()
  readonly property int totalEntryCount: shell.clipboardEntries.length
  property bool wipeArmed: false

  function entryKindLabel(entry) {
    if (entry.kind === "svg") return "Vector image";
    if (entry.kind === "markdown") return "Markdown preview";
    if (entry.kind === "html") return "HTML preview";
    if (entry.kind === "image") return "Full-resolution preview";
    return "Text";
  }

  function entryIcon(entry) {
    if (entry.kind === "svg") return "SVG";
    if (entry.kind === "markdown") return "MD";
    if (entry.kind === "html") return "</>";
    return entry.kind === "image" ? "󰋩" : "󰅇";
  }

  Layout.fillWidth: true
  Layout.fillHeight: true
  spacing: 10

  onEntriesChanged: Qt.callLater(() => clipboardList.positionViewAtBeginning())

  Timer {
    id: wipeConfirmTimer

    interval: 2600
    onTriggered: clipboardWidget.wipeArmed = false
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 8

    TextField {
      id: clipboardSearch

      Layout.fillWidth: true
      implicitHeight: 40
      leftPadding: 38
      rightPadding: clearSearch.visible ? 38 : 12
      text: shell.clipboardFilter
      placeholderText: "Search text, files and image details"
      color: Theme.text
      placeholderTextColor: Theme.muted
      font.family: Theme.fontSans
      font.pixelSize: 12
      cursorDelegate: shell.themedCursor
      selectionColor: Theme.accent
      selectedTextColor: Theme.background
      selectByMouse: true

      background: Rectangle {
        radius: Theme.radiusSm
        color: clipboardSearch.activeFocus ? Theme.surfaceAlt : Theme.surface
        border.color: clipboardSearch.activeFocus ? Theme.accent : Theme.border
        border.width: 1

        Behavior on color {
          ColorAnimation { duration: Theme.motionFast }
        }
        Behavior on border.color {
          ColorAnimation { duration: Theme.motionFast }
        }
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        text: "󰍉"
        color: clipboardSearch.activeFocus ? Theme.accent : Theme.muted
        font.family: Theme.fontIcon
        font.pixelSize: 14
      }

      Rectangle {
        id: clearSearch

        visible: clipboardSearch.text.length > 0
        width: 26
        height: 26
        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        radius: 7
        color: clearSearchMouse.containsMouse ? Theme.accentSoft : "transparent"

        Text {
          anchors.centerIn: parent
          text: "×"
          color: clearSearchMouse.containsMouse ? Theme.text : Theme.muted
          font.family: Theme.fontSans
          font.pixelSize: 16
        }

        MouseArea {
          id: clearSearchMouse

          anchors.fill: parent
          hoverEnabled: true
          scrollGestureEnabled: false
          cursorShape: Qt.PointingHandCursor
          onClicked: clipboardSearch.clear()
        }
      }

      onTextChanged: shell.clipboardFilter = text
      Keys.onEscapePressed: {
        if (shell.clipboardFilter.length > 0)
          shell.clipboardFilter = "";
        else
          shell.closeWidget();
      }
    }

    Rectangle {
      id: refreshButton

      Layout.preferredWidth: 40
      Layout.preferredHeight: 40
      radius: Theme.radiusSm
      color: refreshMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
      border.color: refreshMouse.containsMouse ? Theme.accent : Theme.border
      border.width: 1

      Text {
        anchors.centerIn: parent
        text: "󰑐"
        color: shell.clipboardLoading ? Theme.accent : Theme.text
        font.family: Theme.fontIcon
        font.pixelSize: 15

        RotationAnimator on rotation {
          running: shell.clipboardLoading
          from: 0
          to: 360
          duration: 850
          loops: Animation.Infinite
        }
      }

      MouseArea {
        id: refreshMouse

        anchors.fill: parent
        hoverEnabled: true
        scrollGestureEnabled: false
        cursorShape: Qt.PointingHandCursor
        onClicked: shell.refreshClipboard()
      }

      ToolTip.visible: refreshMouse.containsMouse
      ToolTip.text: "Refresh history"
      ToolTip.delay: 450
    }

    Rectangle {
      id: wipeButton

      Layout.preferredWidth: 40
      Layout.preferredHeight: 40
      radius: Theme.radiusSm
      color: clipboardWidget.wipeArmed || wipeMouse.containsMouse ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.16) : Theme.surface
      border.color: clipboardWidget.wipeArmed || wipeMouse.containsMouse ? Theme.danger : Theme.border
      border.width: 1

      Text {
        anchors.centerIn: parent
        text: clipboardWidget.wipeArmed ? "󰅖" : "󰆴"
        color: clipboardWidget.wipeArmed || wipeMouse.containsMouse ? Theme.danger : Theme.text
        font.family: Theme.fontIcon
        font.pixelSize: 15
      }

      MouseArea {
        id: wipeMouse

        anchors.fill: parent
        hoverEnabled: true
        scrollGestureEnabled: false
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (clipboardWidget.wipeArmed) {
            wipeConfirmTimer.stop();
            clipboardWidget.wipeArmed = false;
            shell.runClipboardAction("wipe", null);
          } else {
            clipboardWidget.wipeArmed = true;
            wipeConfirmTimer.restart();
          }
        }
      }

      ToolTip.visible: wipeMouse.containsMouse
      ToolTip.text: clipboardWidget.wipeArmed ? "Click again to clear everything" : "Clear all history"
      ToolTip.delay: 450
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 2
    Layout.rightMargin: 2
    spacing: 8

    Text {
      text: shell.clipboardFilter.length > 0
        ? clipboardWidget.entries.length + " of " + clipboardWidget.totalEntryCount
        : clipboardWidget.totalEntryCount + (clipboardWidget.totalEntryCount === 1 ? " item" : " items")
      color: Theme.text
      font.family: Theme.fontSans
      font.pixelSize: 11
      font.bold: true
    }

    Rectangle {
      Layout.preferredWidth: 3
      Layout.preferredHeight: 3
      radius: 2
      color: Theme.muted
    }

    Text {
      Layout.fillWidth: true
      text: shell.clipboardLoading ? "Updating history" : "Click an item to copy it"
      color: shell.clipboardLoading ? Theme.accent : Theme.muted
      font.family: Theme.fontSans
      font.pixelSize: 10
      elide: Text.ElideRight
    }

  }

  ListView {
    id: clipboardList

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: 8
    model: clipboardWidget.entries
    cacheBuffer: 420
    reuseItems: true
    boundsBehavior: Flickable.StopAtBounds
    maximumFlickVelocity: 2800
    flickDeceleration: 4800
    pixelAligned: true

    ScrollBar.vertical: ScrollBar {
      id: clipboardScrollBar

      policy: clipboardList.contentHeight > clipboardList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
      interactive: true
      width: 6

      contentItem: Rectangle {
        implicitWidth: 4
        radius: 2
        color: clipboardScrollBar.pressed || clipboardScrollBar.hovered ? Theme.accent : Theme.border
        opacity: clipboardScrollBar.active ? 1 : 0.72

        Behavior on color {
          ColorAnimation { duration: Theme.motionFast }
        }
        Behavior on opacity {
          NumberAnimation { duration: Theme.motionFast }
        }
      }

      background: Item { implicitWidth: 6 }
    }

    delegate: Rectangle {
          id: clipboardRow

          required property var modelData
          readonly property bool imageEntry: (modelData.kind === "image" || modelData.kind === "svg")
            && modelData.imagePath.length > 0
          readonly property bool richEntry: modelData.kind === "markdown" || modelData.kind === "html"
          readonly property bool nearViewport: y + height >= clipboardList.contentY - clipboardList.cacheBuffer
            && y <= clipboardList.contentY + clipboardList.height + clipboardList.cacheBuffer
          readonly property real imagePreviewHeight: imageEntry
            ? Math.min(340, Math.max(140, (width - 20) * modelData.imageHeight / modelData.imageWidth))
            : 0

          width: clipboardList.width - (clipboardScrollBar.visible ? 12 : 0)
          height: clipboardRowContent.implicitHeight + 20
          radius: Theme.radiusMd
          color: clipboardRowMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
          border.color: clipboardRowMouse.containsMouse ? Theme.accent : Theme.border
          border.width: 1

          Behavior on color {
            ColorAnimation { duration: Theme.motionFast }
          }
          Behavior on border.color {
            ColorAnimation { duration: Theme.motionFast }
          }

          Rectangle {
            visible: clipboardRowMouse.containsMouse
            width: 3
            height: parent.height - 22
            anchors.left: parent.left
            anchors.leftMargin: 1
            anchors.verticalCenter: parent.verticalCenter
            radius: 2
            color: Theme.accent
          }

          ColumnLayout {
            id: clipboardRowContent

            z: 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 9

            RowLayout {
              Layout.fillWidth: true
              spacing: 10

              Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 9
                color: clipboardRow.imageEntry || clipboardRow.richEntry ? Theme.accentSoft : Theme.background
                border.color: clipboardRow.imageEntry || clipboardRow.richEntry
                  ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
                  : Theme.border

                Text {
                  anchors.centerIn: parent
                  text: clipboardWidget.entryIcon(clipboardRow.modelData)
                  color: Theme.accent
                  font.family: clipboardRow.richEntry || clipboardRow.modelData.kind === "svg" ? Theme.fontSans : Theme.fontIcon
                  font.pixelSize: clipboardRow.richEntry || clipboardRow.modelData.kind === "svg" ? 9 : 16
                  font.bold: clipboardRow.richEntry || clipboardRow.modelData.kind === "svg"
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                  Layout.fillWidth: true
                  text: clipboardRow.modelData.preview
                  color: Theme.text
                  font.family: Theme.fontSans
                  font.pixelSize: 12
                  font.bold: clipboardRow.imageEntry || clipboardRow.richEntry
                  maximumLineCount: clipboardRow.imageEntry || clipboardRow.richEntry ? 1 : 4
                  wrapMode: Text.Wrap
                  elide: Text.ElideRight
                }

                Text {
                  Layout.fillWidth: true
                  text: clipboardWidget.entryKindLabel(clipboardRow.modelData) + "  •  #" + clipboardRow.modelData.id
                  color: Theme.muted
                  font.family: Theme.fontSans
                  font.pixelSize: 9
                  elide: Text.ElideRight
                }
              }

              Rectangle {
                id: deleteButton

                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 8
                color: deleteMouse.containsMouse ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.16) : Theme.background
                border.color: deleteMouse.containsMouse ? Theme.danger : Theme.border

                Text {
                  anchors.centerIn: parent
                  text: "󰆴"
                  color: deleteMouse.containsMouse ? Theme.danger : Theme.muted
                  font.family: Theme.fontIcon
                  font.pixelSize: 13
                }

                MouseArea {
                  id: deleteMouse

                  anchors.fill: parent
                  hoverEnabled: true
                  scrollGestureEnabled: false
                  cursorShape: Qt.PointingHandCursor
                  onClicked: shell.runClipboardAction("delete", clipboardRow.modelData)
                }

                ToolTip.visible: deleteMouse.containsMouse
                ToolTip.text: "Remove item"
                ToolTip.delay: 450
              }
            }

            Rectangle {
              visible: clipboardRow.imageEntry
              Layout.fillWidth: true
              Layout.preferredHeight: clipboardRow.imagePreviewHeight
              radius: 9
              color: Theme.background
              border.color: clipboardRowMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55) : Theme.border
              clip: true

              Image {
                id: clipboardImage

                anchors.fill: parent
                anchors.margins: 5
                source: clipboardRow.imageEntry && clipboardRow.nearViewport ? "file://" + clipboardRow.modelData.imagePath : ""
                sourceSize.width: clipboardRow.modelData.kind === "svg"
                  ? Math.ceil(width * Screen.devicePixelRatio)
                  : clipboardRow.modelData.imageWidth
                sourceSize.height: clipboardRow.modelData.kind === "svg" ? 0 : clipboardRow.modelData.imageHeight
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                smooth: true
                mipmap: true
                antialiasing: true
                autoTransform: true
                retainWhileLoading: true
              }

              Text {
                anchors.centerIn: parent
                visible: clipboardImage.status === Image.Loading
                text: "Loading full-quality preview..."
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: 10
              }

              Text {
                anchors.centerIn: parent
                visible: clipboardImage.status === Image.Error
                text: "Preview unavailable"
                color: Theme.danger
                font.family: Theme.fontSans
                font.pixelSize: 10
              }
            }

            Rectangle {
              visible: clipboardRow.richEntry
              Layout.fillWidth: true
              Layout.preferredHeight: clipboardRow.richEntry
                ? Math.min(300, Math.max(100, richPreview.implicitHeight + 24))
                : 0
              radius: 9
              color: Theme.background
              border.color: clipboardRowMouse.containsMouse
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                : Theme.border
              clip: true

              Text {
                id: richPreview

                anchors.fill: parent
                anchors.margins: 12
                text: clipboardRow.modelData.richText
                textFormat: clipboardRow.modelData.kind === "markdown" ? Text.MarkdownText : Text.RichText
                color: Theme.text
                linkColor: Theme.accent
                font.family: Theme.fontSans
                font.pixelSize: 11
                wrapMode: Text.Wrap
                maximumLineCount: 14
                elide: Text.ElideRight
              }
            }
          }

          MouseArea {
            id: clipboardRowMouse

            z: 0
            anchors.fill: parent
            hoverEnabled: true
            scrollGestureEnabled: false
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: shell.runClipboardAction("copy", clipboardRow.modelData)
          }
        }

    Text {
      anchors.centerIn: parent
      visible: clipboardList.count === 0
      text: shell.clipboardLoading ? "Loading clipboard..." : (shell.clipboardStatus || "No matches")
      color: Theme.muted
      font.family: Theme.fontSans
      font.pixelSize: 12
      horizontalAlignment: Text.AlignHCenter
      width: parent.width - 24
      wrapMode: Text.Wrap
    }
  }
}
