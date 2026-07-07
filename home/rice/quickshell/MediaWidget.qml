import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

ColumnLayout {
  required property var shell

  Layout.fillWidth: true
  Layout.fillHeight: true
  spacing: 14

  Image {
    visible: shell.mediaPlayer !== null
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: 220
    Layout.preferredHeight: 220
    fillMode: Image.PreserveAspectCrop
    source: shell.mediaPlayer ? shell.mediaPlayer.trackArtUrl : ""
  }

  Text {
    visible: shell.mediaPlayer === null
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: 70
    text: ""
    color: Theme.accent
    font.family: Theme.font
    font.pixelSize: 82
  }

  Text {
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignHCenter
    text: shell.mediaPlayer ? (shell.mediaPlayer.trackTitle || "Unknown title") : "Spotify is not running"
    color: Theme.text
    font.family: Theme.fontSans
    font.bold: true
    font.pixelSize: 17
    wrapMode: Text.Wrap
  }

  Text {
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignHCenter
    text: shell.mediaPlayer ? shell.mediaPlayer.trackArtist : ""
    color: Theme.muted
    font.family: Theme.font
  }

  RowLayout {
    visible: shell.mediaPlayer !== null
    Layout.alignment: Qt.AlignHCenter
    spacing: 28

    Text {
      text: "󰒮"
      color: Theme.text
      font.family: Theme.font
      font.pixelSize: 25
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (shell.mediaPlayer && shell.mediaPlayer.canGoPrevious) shell.mediaPlayer.previous()
      }
    }

    Text {
      text: shell.mediaPlayer && shell.mediaPlayer.isPlaying ? "󰏤" : "󰐊"
      color: Theme.accent
      font.family: Theme.font
      font.pixelSize: 30
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (shell.mediaPlayer && shell.mediaPlayer.canTogglePlaying) shell.mediaPlayer.togglePlaying()
      }
    }

    Text {
      text: "󰒭"
      color: Theme.text
      font.family: Theme.font
      font.pixelSize: 25
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (shell.mediaPlayer && shell.mediaPlayer.canGoNext) shell.mediaPlayer.next()
      }
    }
  }

  Rectangle {
    visible: shell.mediaPlayer === null
    Layout.fillWidth: true
    Layout.preferredHeight: 42
    radius: Theme.radiusSm
    color: Theme.surface

    Text {
      anchors.centerIn: parent
      text: "  Open Spotify"
      color: Theme.accent
      font.family: Theme.font
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: Quickshell.execDetached(["spotify"])
    }
  }
}
