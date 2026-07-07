import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs

ColumnLayout {
  required property var shell

  Layout.fillWidth: true
  Layout.fillHeight: true
  spacing: 9

  RowLayout {
    Layout.fillWidth: true
    spacing: 8

    TextField {
      Layout.fillWidth: true
      implicitHeight: 36
      text: shell.clipboardFilter
      placeholderText: "Search history"
      color: Theme.text
      placeholderTextColor: Theme.muted
      font.family: Theme.font
      font.pixelSize: 12
      cursorDelegate: shell.themedCursor
      selectionColor: Theme.accent
      selectedTextColor: Theme.background
      selectByMouse: true
      background: Rectangle {
        radius: 9
        color: Theme.surface
        border.color: parent.activeFocus ? Theme.accent : Theme.border
        border.width: 1
      }
      onTextChanged: shell.clipboardFilter = text
      Keys.onEscapePressed: {
        if (shell.clipboardFilter.length > 0) shell.clipboardFilter = "";
        else shell.closeWidget();
      }
    }

    Rectangle {
      Layout.preferredWidth: 36
      Layout.preferredHeight: 36
      radius: 9
      color: Theme.surface
      Text { anchors.centerIn: parent; text: "󰑐"; color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: shell.refreshClipboard()
      }
    }

    Rectangle {
      Layout.preferredWidth: 36
      Layout.preferredHeight: 36
      radius: 9
      color: Theme.surface
      Text { anchors.centerIn: parent; text: "󰆴"; color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: shell.runClipboardAction("wipe", null)
      }
    }
  }

  ListView {
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: 7
    model: shell.filteredClipboardEntries()

    delegate: Rectangle {
      id: clipboardRow
      required property var modelData
      width: ListView.view.width
      height: 54
      radius: 10
      color: clipboardRowMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
      border.color: clipboardRowMouse.containsMouse ? Theme.accent : Theme.border
      border.width: 1

      RowLayout {
        z: 1
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Text {
          text: "󰅇"
          color: Theme.accent
          font.family: Theme.fontIcon
          font.pixelSize: 18
          Layout.preferredWidth: 24
          horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text {
            Layout.fillWidth: true
            text: clipboardRow.modelData.preview
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 12
            maximumLineCount: 2
            wrapMode: Text.Wrap
            elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            text: "#" + clipboardRow.modelData.id
            color: Theme.muted
            font.family: Theme.fontSans
            font.pixelSize: 10
            elide: Text.ElideRight
          }
        }

        Rectangle {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 30
          radius: 8
          color: Theme.background
          border.color: Theme.border
          Text { anchors.centerIn: parent; text: "×"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 16 }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: shell.runClipboardAction("delete", clipboardRow.modelData)
          }
        }
      }

      MouseArea {
        id: clipboardRowMouse
        z: 0
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: shell.runClipboardAction("copy", clipboardRow.modelData)
      }
    }

    Text {
      anchors.centerIn: parent
      visible: parent.count === 0
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
