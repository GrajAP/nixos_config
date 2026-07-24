import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs

ColumnLayout {
  id: mediaRoot

  required property var shell
  readonly property var player: shell.mediaPlayer
  property real lastAudibleVolume: 0.65

  Layout.fillWidth: true
  Layout.fillHeight: true
  spacing: 9

  function formatTime(seconds) {
    const value = Math.max(0, Math.floor(Number(seconds) || 0));
    const minutes = Math.floor(value / 60);
    const rest = value % 60;
    return minutes + ":" + String(rest).padStart(2, "0");
  }

  function seekBy(seconds) {
    if (!mediaRoot.player || !mediaRoot.player.canSeek)
      return;
    mediaRoot.player.seek(seconds);
  }

  function cycleLoopMode() {
    if (!mediaRoot.player || !mediaRoot.player.canControl || !mediaRoot.player.loopSupported)
      return;
    if (mediaRoot.player.loopState === MprisLoopState.None)
      mediaRoot.player.loopState = MprisLoopState.Playlist;
    else if (mediaRoot.player.loopState === MprisLoopState.Playlist)
      mediaRoot.player.loopState = MprisLoopState.Track;
    else
      mediaRoot.player.loopState = MprisLoopState.None;
  }

  function loopLabel() {
    if (!mediaRoot.player || !mediaRoot.player.loopSupported)
      return "Repeat unavailable";
    if (mediaRoot.player.loopState === MprisLoopState.Track)
      return "Repeat one";
    if (mediaRoot.player.loopState === MprisLoopState.Playlist)
      return "Repeat all";
    return "Repeat off";
  }

  function toggleMute() {
    if (!mediaRoot.player || !mediaRoot.player.canControl || !mediaRoot.player.volumeSupported)
      return;
    if (mediaRoot.player.volume > 0.01) {
      mediaRoot.lastAudibleVolume = mediaRoot.player.volume;
      mediaRoot.player.volume = 0;
    } else {
      mediaRoot.player.volume = Math.max(0.05, mediaRoot.lastAudibleVolume);
    }
  }

  Timer {
    interval: 500
    running: mediaRoot.player !== null && mediaRoot.player.isPlaying && mediaRoot.player.positionSupported
    repeat: true
    onTriggered: mediaRoot.player.positionChanged()
  }

  Rectangle {
    visible: mediaRoot.player !== null
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: 154
    Layout.preferredHeight: 154
    radius: 14
    clip: true
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    Image {
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      source: mediaRoot.player ? mediaRoot.player.trackArtUrl : ""
    }
  }

  Item {
    visible: mediaRoot.player === null
    Layout.fillWidth: true
    Layout.preferredHeight: 220

    ColumnLayout {
      anchors.centerIn: parent
      spacing: 12

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: ""
        color: Theme.accent
        font.family: Theme.fontIcon
        font.pixelSize: 82
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "Spotify is not running"
        color: Theme.text
        font.family: Theme.fontSans
        font.bold: true
        font.pixelSize: 17
      }
    }
  }

  ColumnLayout {
    visible: mediaRoot.player !== null
    Layout.fillWidth: true
    spacing: 2

    Text {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: mediaRoot.player ? (mediaRoot.player.trackTitle || "Unknown title") : ""
      color: Theme.text
      font.family: Theme.fontSans
      font.bold: true
      font.pixelSize: 17
      elide: Text.ElideRight
    }

    Text {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: {
        if (!mediaRoot.player)
          return "";
        const artist = mediaRoot.player.trackArtist || "Unknown artist";
        const album = mediaRoot.player.trackAlbum || "";
        return album.length > 0 ? artist + " · " + album : artist;
      }
      color: Theme.muted
      font.family: Theme.fontSans
      font.pixelSize: 11
      elide: Text.ElideRight
    }
  }

  ColumnLayout {
    visible: mediaRoot.player !== null
    Layout.fillWidth: true
    spacing: 2

    Slider {
      id: seekSlider

      Layout.fillWidth: true
      implicitHeight: 20
      from: 0
      to: mediaRoot.player && mediaRoot.player.lengthSupported ? Math.max(1, mediaRoot.player.length) : 1
      value: mediaRoot.player && mediaRoot.player.positionSupported ? Math.min(to, mediaRoot.player.position) : 0
      enabled: mediaRoot.player !== null && mediaRoot.player.canSeek && mediaRoot.player.positionSupported && mediaRoot.player.lengthSupported
      onMoved: {
        if (enabled)
          mediaRoot.player.position = value;
      }

      background: Rectangle {
        x: seekSlider.leftPadding
        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
        width: seekSlider.availableWidth
        height: 5
        radius: 3
        color: Theme.surfaceAlt

        Rectangle {
          width: seekSlider.visualPosition * parent.width
          height: parent.height
          radius: parent.radius
          color: seekSlider.enabled ? Theme.accent : Theme.muted
        }
      }

      handle: Rectangle {
        x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
        implicitWidth: seekSlider.pressed ? 15 : 11
        implicitHeight: implicitWidth
        radius: width / 2
        color: seekSlider.enabled ? Theme.accent : Theme.muted
        border.color: Theme.background
        border.width: 2
      }
    }

    RowLayout {
      Layout.fillWidth: true

      Text {
        text: mediaRoot.player ? mediaRoot.formatTime(mediaRoot.player.position) : "0:00"
        color: Theme.muted
        font.family: Theme.fontMono
        font.pixelSize: 10
      }

      Item {
        Layout.fillWidth: true
      }

      Text {
        text: mediaRoot.player ? mediaRoot.formatTime(mediaRoot.player.length) : "0:00"
        color: Theme.muted
        font.family: Theme.fontMono
        font.pixelSize: 10
      }
    }
  }

  RowLayout {
    visible: mediaRoot.player !== null
    Layout.alignment: Qt.AlignHCenter
    spacing: 12

    Rectangle {
      implicitWidth: 42
      implicitHeight: 38
      radius: 10
      color: Theme.surface
      opacity: mediaRoot.player && mediaRoot.player.canSeek ? 1 : 0.45

      Text {
        anchors.centerIn: parent
        text: "󰑟"
        color: Theme.text
        font.family: Theme.fontIcon
        font.pixelSize: 18
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        text: "10"
        color: Theme.muted
        font.family: Theme.fontSans
        font.pixelSize: 8
        font.bold: true
      }

      MouseArea {
        anchors.fill: parent
        enabled: mediaRoot.player !== null && mediaRoot.player.canSeek
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mediaRoot.seekBy(-10)
      }
    }

    Rectangle {
      implicitWidth: 42
      implicitHeight: 42
      radius: 11
      color: Theme.surface
      opacity: mediaRoot.player && mediaRoot.player.canGoPrevious ? 1 : 0.45

      Text {
        anchors.centerIn: parent
        text: "󰒮"
        color: Theme.text
        font.family: Theme.fontIcon
        font.pixelSize: 24
      }

      MouseArea {
        anchors.fill: parent
        enabled: mediaRoot.player !== null && mediaRoot.player.canGoPrevious
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mediaRoot.player.previous()
      }
    }

    Rectangle {
      implicitWidth: 52
      implicitHeight: 52
      radius: 16
      color: Theme.accent
      opacity: mediaRoot.player && mediaRoot.player.canTogglePlaying ? 1 : 0.55

      Text {
        anchors.centerIn: parent
        text: mediaRoot.player && mediaRoot.player.isPlaying ? "󰏤" : "󰐊"
        color: Theme.background
        font.family: Theme.fontIcon
        font.pixelSize: 29
      }

      MouseArea {
        anchors.fill: parent
        enabled: mediaRoot.player !== null && mediaRoot.player.canTogglePlaying
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mediaRoot.player.togglePlaying()
      }
    }

    Rectangle {
      implicitWidth: 42
      implicitHeight: 42
      radius: 11
      color: Theme.surface
      opacity: mediaRoot.player && mediaRoot.player.canGoNext ? 1 : 0.45

      Text {
        anchors.centerIn: parent
        text: "󰒭"
        color: Theme.text
        font.family: Theme.fontIcon
        font.pixelSize: 24
      }

      MouseArea {
        anchors.fill: parent
        enabled: mediaRoot.player !== null && mediaRoot.player.canGoNext
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mediaRoot.player.next()
      }
    }

    Rectangle {
      implicitWidth: 42
      implicitHeight: 38
      radius: 10
      color: Theme.surface
      opacity: mediaRoot.player && mediaRoot.player.canSeek ? 1 : 0.45

      Text {
        anchors.centerIn: parent
        text: "󰑐"
        color: Theme.text
        font.family: Theme.fontIcon
        font.pixelSize: 18
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        text: "10"
        color: Theme.muted
        font.family: Theme.fontSans
        font.pixelSize: 8
        font.bold: true
      }

      MouseArea {
        anchors.fill: parent
        enabled: mediaRoot.player !== null && mediaRoot.player.canSeek
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mediaRoot.seekBy(10)
      }
    }
  }

  RowLayout {
    visible: mediaRoot.player !== null
    Layout.fillWidth: true
    spacing: 8

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 34
      radius: 9
      color: mediaRoot.player && mediaRoot.player.shuffle ? Theme.accent : Theme.surface
      opacity: mediaRoot.player && mediaRoot.player.shuffleSupported ? 1 : 0.45

      Text {
        anchors.centerIn: parent
        text: "󰒝  Shuffle"
        color: mediaRoot.player && mediaRoot.player.shuffle ? Theme.background : Theme.text
        font.family: Theme.fontSans
        font.pixelSize: 11
        font.bold: true
      }

      MouseArea {
        anchors.fill: parent
        enabled: mediaRoot.player !== null && mediaRoot.player.canControl && mediaRoot.player.shuffleSupported
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mediaRoot.player.shuffle = !mediaRoot.player.shuffle
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 34
      radius: 9
      color: mediaRoot.player && mediaRoot.player.loopState !== MprisLoopState.None ? Theme.accent : Theme.surface
      opacity: mediaRoot.player && mediaRoot.player.loopSupported ? 1 : 0.45

      Text {
        anchors.centerIn: parent
        text: "󰑖  " + mediaRoot.loopLabel()
        color: mediaRoot.player && mediaRoot.player.loopState !== MprisLoopState.None ? Theme.background : Theme.text
        font.family: Theme.fontSans
        font.pixelSize: 11
        font.bold: true
      }

      MouseArea {
        anchors.fill: parent
        enabled: mediaRoot.player !== null && mediaRoot.player.canControl && mediaRoot.player.loopSupported
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mediaRoot.cycleLoopMode()
      }
    }
  }

  RowLayout {
    visible: mediaRoot.player !== null
    Layout.fillWidth: true
    spacing: 8

    Text {
      text: mediaRoot.player && mediaRoot.player.volume <= 0.01 ? "󰖁" : "󰕾"
      color: mediaRoot.player && mediaRoot.player.volumeSupported ? Theme.text : Theme.muted
      font.family: Theme.fontIcon
      font.pixelSize: 18

      MouseArea {
        anchors.fill: parent
        enabled: mediaRoot.player !== null && mediaRoot.player.canControl && mediaRoot.player.volumeSupported
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mediaRoot.toggleMute()
      }
    }

    Slider {
      id: volumeSlider

      Layout.fillWidth: true
      implicitHeight: 24
      from: 0
      to: 1
      stepSize: 0.01
      value: mediaRoot.player && mediaRoot.player.volumeSupported ? mediaRoot.player.volume : 0
      enabled: mediaRoot.player !== null && mediaRoot.player.canControl && mediaRoot.player.volumeSupported
      onMoved: {
        if (!enabled)
          return;
        mediaRoot.player.volume = value;
        if (value > 0.01)
          mediaRoot.lastAudibleVolume = value;
      }

      background: Rectangle {
        x: volumeSlider.leftPadding
        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
        width: volumeSlider.availableWidth
        height: 5
        radius: 3
        color: Theme.surfaceAlt

        Rectangle {
          width: volumeSlider.visualPosition * parent.width
          height: parent.height
          radius: parent.radius
          color: volumeSlider.enabled ? Theme.accent : Theme.muted
        }
      }

      handle: Rectangle {
        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
        implicitWidth: 12
        implicitHeight: 12
        radius: 6
        color: volumeSlider.enabled ? Theme.accent : Theme.muted
      }
    }

    Text {
      Layout.preferredWidth: 36
      horizontalAlignment: Text.AlignRight
      text: mediaRoot.player && mediaRoot.player.volumeSupported ? Math.round(mediaRoot.player.volume * 100) + "%" : "N/A"
      color: Theme.muted
      font.family: Theme.fontMono
      font.pixelSize: 10
    }
  }

  Rectangle {
    visible: mediaRoot.player === null
    Layout.fillWidth: true
    Layout.preferredHeight: 42
    radius: Theme.radiusSm
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    Text {
      anchors.centerIn: parent
      text: "  Open Spotify"
      color: Theme.accent
      font.family: Theme.fontSans
      font.bold: true
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: Quickshell.execDetached(["@spotifyLauncher@"])
    }
  }

  Item {
    Layout.fillHeight: true
  }
}
